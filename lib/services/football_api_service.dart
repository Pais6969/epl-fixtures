import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/match_model.dart';
import '../models/standing_model.dart';

/// Error dengan pesan yang sudah ramah dibaca pengguna.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FootballApiService {
  FootballApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Mengambil seluruh jadwal & hasil Premier League satu musim.
  /// Satu kali request saja (hemat batas 10 request/menit); pemilihan
  /// matchday dan filter status dilakukan di sisi aplikasi.
  Future<FixturesData> fetchFixtures() {
    return _guard(() async {
      final json = await _get('/competitions/${ApiConfig.competition}/matches');
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
  Future<List<StandingRow>> fetchStandings() {
    return _guard(() async {
      final json =
          await _get('/competitions/${ApiConfig.competition}/standings');
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

  /// Mengirim GET ke API dan memeriksa status respons.
  Future<Map<String, dynamic>> _get(String path) async {
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
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      case 400:
      case 403:
        throw ApiException(
          'Token tidak valid atau tidak punya akses ke data ini '
          '(kode ${response.statusCode}).',
        );
      case 404:
        throw const ApiException('Data yang diminta tidak ditemukan (404).');
      case 429:
        throw const ApiException(
          'Terlalu banyak permintaan (maksimal 10 per menit). '
          'Tunggu sebentar lalu coba lagi.',
        );
      default:
        throw ApiException(
          'Server bermasalah (kode ${response.statusCode}). Coba lagi nanti.',
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
        'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.',
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
