import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/match_model.dart';
import '../models/scorer_model.dart';
import '../models/standing_model.dart';
import '../models/team_detail_model.dart';
import 'cache_store.dart';

/// Error dengan pesan yang sudah ramah dibaca pengguna.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// Kode status HTTP bila error berasal dari respons server.
  final int? statusCode;

  /// Data tidak termasuk paket gratis football-data.org.
  bool get isRestricted => statusCode == 403;

  @override
  String toString() => message;
}

class FootballApiService {
  FootballApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Satu objek bersama untuk seluruh halaman.
  static final FootballApiService shared = FootballApiService();

  final http.Client _client;

  /// Berisi waktu penyimpanan data bila data terakhir yang ditampilkan
  /// berasal dari cache karena koneksi gagal (mode offline).
  /// Null berarti data terakhir berhasil diambil dari server.
  final ValueNotifier<DateTime?> offlineSince = ValueNotifier(null);

  // Lama data dianggap masih segar sehingga tidak perlu meminta ulang ke API.
  static const _ttlFixtures = Duration(minutes: 2);
  static const _ttlStandings = Duration(minutes: 10);
  static const _ttlScorers = Duration(minutes: 30);
  static const _ttlTeam = Duration(days: 1);

  /// Mengambil seluruh jadwal & hasil Premier League satu musim.
  /// Satu kali request saja (hemat batas 10 request/menit); pemilihan
  /// matchday dan filter status dilakukan di sisi aplikasi.
  Future<FixturesData> fetchFixtures({bool force = false}) {
    return _guard(() async {
      final json = await _getCached(
        '/competitions/${ApiConfig.competition}/matches',
        ttl: _ttlFixtures,
        force: force,
      );
      final raw = json['matches'] as List<dynamic>? ?? const <dynamic>[];
      if (raw.isEmpty) {
        throw const ApiException('Belum ada data pertandingan dari server.');
      }

      final matches = raw
          .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

      return FixturesData(
        matches: matches,
        currentMatchday: _currentMatchday(raw, matches),
      );
    });
  }

  /// Mengambil klasemen (tabel TOTAL) Premier League.
  Future<List<StandingRow>> fetchStandings({bool force = false}) {
    return _guard(() async {
      final json = await _getCached(
        '/competitions/${ApiConfig.competition}/standings',
        ttl: _ttlStandings,
        force: force,
      );
      final tables = (json['standings'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (tables.isEmpty) {
        throw const ApiException('Data klasemen belum tersedia.');
      }
      final total = tables.firstWhere(
        (s) => s['type'] == 'TOTAL',
        orElse: () => tables.first,
      );
      final table = total['table'] as List<dynamic>? ?? const <dynamic>[];
      return table
          .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// [UAS] Daftar pencetak gol terbanyak.
  Future<List<ScorerModel>> fetchScorers({int limit = 20, bool force = false}) {
    return _guard(() async {
      final json = await _getCached(
        '/competitions/${ApiConfig.competition}/scorers?limit=$limit',
        ttl: _ttlScorers,
        force: force,
      );
      final raw = json['scorers'] as List<dynamic>? ?? const <dynamic>[];
      return raw
          .map((e) => ScorerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// [UAS] Detail klub: stadion, alamat, pelatih, dan skuad.
  Future<TeamDetail> fetchTeam(int teamId, {bool force = false}) {
    return _guard(() async {
      final json = await _getCached(
        '/teams/$teamId',
        ttl: _ttlTeam,
        force: force,
      );
      return TeamDetail.fromJson(json);
    });
  }

  /// Matchday saat ini: dari field season.currentMatchday jika ada,
  /// jika tidak, matchday pertandingan pertama yang belum selesai.
  int _currentMatchday(List<dynamic> raw, List<MatchModel> matches) {
    final first = raw.first as Map<String, dynamic>;
    final season = first['season'] as Map<String, dynamic>?;
    final fromApi = (season?['currentMatchday'] as num?)?.toInt();
    if (fromApi != null && fromApi > 0) return fromApi;

    final unfinished = matches.where((m) => !m.isFinished).toList();
    return unfinished.isNotEmpty
        ? unfinished.first.matchday
        : matches.last.matchday;
  }

  /// [UAS] Mengambil data dengan cache:
  /// 1. Bila cache masih segar (umur < [ttl]) dan tidak dipaksa, pakai cache.
  /// 2. Bila tidak, minta ke server lalu simpan hasilnya ke cache.
  /// 3. Bila permintaan gagal tetapi cache ada, tampilkan cache (mode offline).
  Future<Map<String, dynamic>> _getCached(
    String path, {
    required Duration ttl,
    bool force = false,
  }) async {
    final cached = await CacheStore.read(path);
    if (!force && cached != null && cached.age < ttl) {
      return _decode(cached.body);
    }

    try {
      final body = await _get(path);
      await CacheStore.write(path, body);
      offlineSince.value = null;
      return _decode(body);
    } catch (e) {
      // Data yang memang tidak tersedia (403/404) tidak diganti cache.
      final unavailable =
          e is ApiException && (e.statusCode == 403 || e.statusCode == 404);
      if (cached != null && !unavailable) {
        offlineSince.value = cached.savedAt;
        return _decode(cached.body);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _decode(String body) =>
      jsonDecode(body) as Map<String, dynamic>;

  /// Mengirim GET ke API, memeriksa status respons, lalu mengembalikan
  /// isi respons (teks JSON).
  Future<String> _get(String path) async {
    if (!ApiConfig.hasToken) {
      throw const ApiException(
        'Token API belum diisi. Jalankan aplikasi dengan '
        '--dart-define=FOOTBALL_DATA_TOKEN=tokenmu',
      );
    }

    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'X-Auth-Token': ApiConfig.token},
    ).timeout(const Duration(seconds: 15));

    switch (response.statusCode) {
      case 200:
        return utf8.decode(response.bodyBytes);
      case 400:
        throw const ApiException(
          'Permintaan tidak valid (kode 400).',
          statusCode: 400,
        );
      case 403:
        throw const ApiException(
          'Data ini tidak termasuk paket gratis football-data.org, '
          'atau token tidak punya akses (kode 403).',
          statusCode: 403,
        );
      case 404:
        throw const ApiException(
          'Data yang diminta tidak ditemukan (404).',
          statusCode: 404,
        );
      case 429:
        throw const ApiException(
          'Terlalu banyak permintaan (maksimal 10 per menit). '
          'Tunggu sebentar lalu coba lagi.',
          statusCode: 429,
        );
      default:
        throw ApiException(
          'Server bermasalah (kode ${response.statusCode}). Coba lagi nanti.',
          statusCode: response.statusCode,
        );
    }
  }

  /// Menerjemahkan semua jenis kegagalan menjadi [ApiException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        'Tidak ada koneksi internet dan belum ada data tersimpan. '
        'Periksa jaringanmu lalu coba lagi.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak bisa terhubung ke server. Periksa jaringanmu lalu coba lagi.',
      );
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    } on FormatException {
      throw const ApiException('Data dari server tidak dapat dibaca.');
    } on TypeError {
      throw const ApiException('Format data dari server tidak sesuai.');
    }
  }
}
