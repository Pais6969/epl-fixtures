import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/match_model.dart';
import 'football_api_service.dart';
import 'location_service.dart';
import 'settings_service.dart';
import 'weather_service.dart';

/// [UAS] Notifikasi lokal: pengingat kick-off pertandingan.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'kickoff_reminder';
  static const _channelName = 'Pengingat kick-off';
  static const _testId = 1;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Meminta izin notifikasi (wajib di Android 13 ke atas).
  static Future<bool> requestPermission() async {
    return await _android?.requestNotificationsPermission() ?? true;
  }

  static NotificationDetails _details(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Pengingat sebelum pertandingan Premier League dimulai',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  /// Notifikasi langsung, untuk menguji apakah notifikasi berjalan.
  static Future<void> showTest() async {
    const body = 'Notifikasi aktif. Kamu akan diingatkan sebelum kick-off.';
    await _plugin.show(
      id: _testId,
      title: 'EPL Fixtures',
      body: body,
      notificationDetails: _details(body),
    );
  }

  /// Menjadwalkan notifikasi [minutesBefore] menit sebelum kick-off.
  /// Mengembalikan false bila waktunya sudah lewat.
  static Future<bool> scheduleKickoff(
    MatchModel match, {
    required int minutesBefore,
    String? extra,
  }) async {
    final when = match.kickoff.toUtc().subtract(Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now().toUtc())) return false;

    final jam = DateFormat('HH:mm').format(match.kickoff);
    final body = [
      'Kick-off $minutesBefore menit lagi, pukul $jam.',
      ?extra,
    ].join(' ');

    await _plugin.zonedSchedule(
      id: match.id,
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: _details(body),
      // Tanpa izin alarm tepat waktu; bisa bergeser beberapa menit.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: '${match.homeTeam.shortName} vs ${match.awayTeam.shortName}',
      body: body,
      payload: '${match.id}',
    );
    return true;
  }

  static Future<void> cancel(int matchId) => _plugin.cancel(id: matchId);

  static Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();
}

/// [UAS] Mengatur pengingat manual dan pengingat otomatis klub favorit.
class ReminderService {
  ReminderService._();

  static AppSettings get _s => AppSettings.instance;

  /// Memasang / melepas pengingat untuk satu pertandingan.
  /// Mengembalikan pesan untuk ditampilkan ke pengguna.
  static Future<String> toggle(MatchModel match) async {
    if (_s.hasReminder(match.id)) {
      await NotificationService.cancel(match.id);
      await _s.setManualReminders({..._s.manualReminders}..remove(match.id));
      await _s.setAutoReminders({..._s.autoReminders}..remove(match.id));
      return 'Pengingat dibatalkan.';
    }

    final allowed = await NotificationService.requestPermission();
    if (!allowed) {
      return 'Izin notifikasi ditolak. Aktifkan di pengaturan perangkat.';
    }
    final extra = await _weatherNote(match);
    final ok = await NotificationService.scheduleKickoff(
      match,
      minutesBefore: _s.reminderMinutes,
      extra: extra,
    );
    if (!ok) return 'Waktu pengingat sudah lewat.';
    await _s.setManualReminders({..._s.manualReminders, match.id});
    return 'Pengingat dipasang ${_s.reminderMinutes} menit sebelum kick-off.';
  }

  /// Menyamakan pengingat otomatis dengan jadwal klub favorit:
  /// laga klub favorit dalam 14 hari ke depan diberi pengingat.
  static Future<void> syncFavorite(FixturesData data) async {
    final favId = _s.favoriteTeamId;
    final wanted = <int>{};
    final now = DateTime.now();

    if (_s.autoRemindFavorite && favId != null) {
      for (final m in data.matches) {
        final involved = m.homeTeam.id == favId || m.awayTeam.id == favId;
        final soon = m.kickoff.isAfter(now) &&
            m.kickoff.isBefore(now.add(const Duration(days: 14)));
        if (involved && soon && m.isUpcoming) wanted.add(m.id);
      }
    }

    // Lepas pengingat otomatis yang sudah tidak diperlukan.
    for (final id in _s.autoReminders.difference(wanted)) {
      if (!_s.manualReminders.contains(id)) {
        await NotificationService.cancel(id);
      }
    }

    // Pasang ulang semua pengingat otomatis (menit pengingat bisa berubah).
    if (wanted.isNotEmpty) await NotificationService.requestPermission();
    final scheduled = <int>{};
    for (final m in data.matches.where((m) => wanted.contains(m.id))) {
      if (_s.manualReminders.contains(m.id)) continue;
      final ok = await NotificationService.scheduleKickoff(
        m,
        minutesBefore: _s.reminderMinutes,
        extra: 'Klub favoritmu akan bertanding!',
      );
      if (ok) scheduled.add(m.id);
    }
    await _s.setAutoReminders(scheduled);
  }

  /// Dipanggil setelah klub favorit / pengaturan pengingat berubah.
  static Future<void> resync() async {
    try {
      final data = await FootballApiService.shared.fetchFixtures();
      await syncFavorite(data);
    } catch (_) {
      // Gagal memuat jadwal: pengingat disinkronkan lagi saat jadwal dimuat.
    }
  }

  /// Info cuaca stadion saat kick-off untuk isi notifikasi (bila tersedia).
  static Future<String?> _weatherNote(MatchModel match) async {
    try {
      final team = await FootballApiService.shared.fetchTeam(match.homeTeam.id);
      final pos = await LocationService.coordinatesOfAny(team.geocodeCandidates);
      if (pos == null) return null;
      final fc = await WeatherService.forecast(pos.latitude, pos.longitude);
      final w = fc.at(match.kickoff);
      if (w == null) return null;
      return 'Prakiraan di ${team.venue ?? 'stadion'}: ${w.kind.label}, '
          '${w.temperature.round()}°C.';
    } catch (_) {
      return null;
    }
  }
}
