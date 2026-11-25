import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;
import 'package:intl/intl.dart';

import '../models/team_model.dart';
import '../models/user_location.dart';
import '../models/weather_model.dart';
import '../services/cache_store.dart';
import '../services/football_api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_pill.dart';
import '../widgets/common.dart';
import '../widgets/team_crest.dart';
import 'club_page.dart';
import 'search_page.dart';

/// [UAS] Halaman baru "Saya": lokasi & cuaca, klub favorit, notifikasi,
/// tampilan (mode gelap), dan data offline.
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final _settings = AppSettings.instance;

  bool _locating = false;
  String? _locationError;
  Future<WeatherForecast>? _weather;
  late Future<List<PendingNotificationRequest>> _pending;
  late Future<int> _cacheCount;

  @override
  void initState() {
    super.initState();
    final loc = _settings.location;
    if (loc != null) _weather = _weatherFor(loc);
    _refreshInfo();
  }

  Future<WeatherForecast> _weatherFor(UserLocation loc) =>
      WeatherService.forecast(loc.latitude, loc.longitude);

  void _refreshInfo() {
    _pending = NotificationService.pending();
    _cacheCount = CacheStore.count();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    UserLocation? loc;
    String? error;
    try {
      loc = await LocationService.getCurrentLocation();
    } on LocationException catch (e) {
      error = e.message;
    } catch (e) {
      debugPrint('Ambil lokasi gagal: $e');
      error = _settings.location == null
          ? 'Lokasi gagal diambil. Coba lagi.'
          : 'Gagal memperbarui lokasi, yang tampil adalah lokasi '
              'terakhir yang tersimpan.';
    }

    final result = loc;
    if (result != null) await _settings.setLocation(result);
    if (!mounted) return;
    setState(() {
      _locating = false;
      // Berhasil -> pesan error dihapus; gagal -> tampilkan penyebabnya.
      _locationError = result == null ? error : null;
      if (result != null) _weather = _weatherFor(result);
    });
  }

  Future<void> _clearLocation() async {
    await _settings.setLocation(null);
    if (!mounted) return;
    setState(() {
      _weather = null;
      _locationError = null;
    });
    _snack('Lokasi dihapus dari aplikasi.');
  }

  Future<void> _pickFavorite() async {
    final team = await Navigator.of(context).push<TeamModel>(
      MaterialPageRoute(builder: (_) => const SearchPage(pickMode: true)),
    );
    if (team == null) return;
    await _settings.setFavoriteTeam(team);
    await ReminderService.resync();
    if (!mounted) return;
    setState(_refreshInfo);
    _snack('${team.shortName} jadi klub favoritmu.');
  }

  Future<void> _resync() async {
    await ReminderService.resync();
    if (mounted) setState(_refreshInfo);
  }

  Future<void> _testNotification() async {
    final ok = await NotificationService.requestPermission();
    if (!ok) {
      _snack('Izin notifikasi ditolak. Aktifkan di pengaturan perangkat.');
      return;
    }
    await NotificationService.showTest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saya')),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () async => setState(_refreshInfo),
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            children: [
              _locationCard(),
              _favoriteCard(),
              _notificationCard(),
              _themeCard(),
              _dataCard(),
              _aboutCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Lokasi

  Widget _locationCard() {
    final p = context.palette;
    final loc = _settings.location;
    final offset = DateTime.now().timeZoneOffset;
    final tzText = '${DateTime.now().timeZoneName} '
        '(UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()})';

    return SectionCard(
      title: 'Lokasiku',
      icon: Icons.my_location,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loc == null)
            Text(
              'Izinkan lokasi agar jam tayang, jarak ke stadion, dan cuaca '
              'di kotamu bisa ditampilkan.',
              style: TextStyle(color: p.muted),
            )
          else ...[
            Text(
              loc.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '${loc.latitude.toStringAsFixed(4)}, '
              '${loc.longitude.toStringAsFixed(4)} · zona waktu $tzText',
              style: TextStyle(color: p.muted, fontSize: 12.5),
            ),
            Text(
              'Diperbarui ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(loc.savedAt)}',
              style: TextStyle(color: p.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            FutureBuilder<WeatherForecast>(
              future: _weather,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError || !snap.hasData) {
                  return Text(
                    'Cuaca saat ini gagal dimuat.',
                    style: TextStyle(color: p.muted),
                  );
                }
                final now = snap.data!.current;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WeatherSummary(
                      point: now,
                      caption: 'Cuaca di ${loc.city} sekarang',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      now.kind.isWet
                          ? 'Sedang hujan, cocok nonton di rumah saja.'
                          : 'Cuaca aman untuk nonton bareng di luar.',
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                );
              },
            ),
          ],
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Text(_locationError!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _locating ? null : _locate,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed),
                  label: Text(loc == null
                      ? 'Gunakan lokasi saya'
                      : 'Perbarui lokasi'),
                ),
              ),
              if (loc != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Hapus lokasi tersimpan',
                  onPressed: _locating ? null : _clearLocation,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Klub favorit

  Widget _favoriteCard() {
    final p = context.palette;
    final fav = _settings.favoriteTeam;
    return SectionCard(
      title: 'Klub favorit',
      icon: Icons.star_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fav == null)
            Text(
              'Belum ada. Pilih klub favorit agar jadwalnya ditandai dan '
              'diingatkan otomatis.',
              style: TextStyle(color: p.muted),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: TeamCrest(url: fav.crest, size: 36),
              title: Text(
                fav.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Ketuk untuk melihat profil klub'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ClubPage(team: fav)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFavorite,
                  icon: const Icon(Icons.search),
                  label: Text(fav == null ? 'Pilih klub' : 'Ganti klub'),
                ),
              ),
              if (fav != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Hapus favorit',
                  onPressed: () async {
                    await _settings.setFavoriteTeam(null);
                    await _resync();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Notifikasi

  Widget _notificationCard() {
    final p = context.palette;
    return SectionCard(
      title: 'Notifikasi',
      icon: Icons.notifications_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pengingat otomatis klub favorit'),
            subtitle: const Text('Untuk laga dalam 14 hari ke depan'),
            value: _settings.autoRemindFavorite,
            onChanged: (v) async {
              await _settings.setAutoRemindFavorite(v);
              await _resync();
            },
          ),
          const SizedBox(height: 4),
          Text('Ingatkan sebelum kick-off', style: TextStyle(color: p.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 30, 60])
                ChoicePill(
                  label: '$m menit',
                  selected: _settings.reminderMinutes == m,
                  onTap: () async {
                    await _settings.setReminderMinutes(m);
                    await _resync();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PendingNotificationRequest>>(
            future: _pending,
            builder: (context, snap) {
              final list = snap.data ?? const <PendingNotificationRequest>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengingat terjadwal: ${list.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final n in list.take(5))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.alarm, size: 16, color: p.muted),
                          const SizedBox(width: 6),
                          Expanded(child: Text(n.title ?? '-')),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testNotification,
            icon: const Icon(Icons.notification_add_outlined),
            label: const Text('Kirim notifikasi uji'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Tampilan

  Widget _themeCard() {
    return SectionCard(
      title: 'Tampilan',
      icon: Icons.dark_mode_outlined,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto),
            label: Text('Sistem'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Terang'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Gelap'),
          ),
        ],
        selected: {_settings.themeMode},
        onSelectionChanged: (s) => _settings.setThemeMode(s.first),
      ),
    );
  }

  // ---------------------------------------------------------- Data offline

  Widget _dataCard() {
    final p = context.palette;
    return SectionCard(
      title: 'Data offline',
      icon: Icons.storage_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<int>(
            future: _cacheCount,
            builder: (context, snap) => Text(
              'Data tersimpan: ${snap.data ?? '-'} respons API. '
              'Data ini ditampilkan saat tidak ada internet.',
              style: TextStyle(color: p.muted),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await CacheStore.clear();
              FootballApiService.shared.offlineSince.value = null;
              if (!mounted) return;
              setState(_refreshInfo);
              _snack('Cache dihapus. Data akan diambil ulang dari server.');
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Hapus data tersimpan'),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    final p = context.palette;
    return SectionCard(
      title: 'Tentang aplikasi',
      icon: Icons.info_outline,
      child: Text(
        'EPL Fixtures versi 2.0 (UAS).\n'
        'Data sepak bola: football-data.org (v4, paket gratis).\n'
        'Data cuaca: Open-Meteo.',
        style: TextStyle(color: p.muted, height: 1.5),
      ),
    );
  }
}
