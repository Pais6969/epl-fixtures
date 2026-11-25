import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/match_model.dart';
import '../models/team_detail_model.dart';
import '../models/team_model.dart';
import '../models/weather_model.dart';
import '../services/football_api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/status_pill.dart';
import '../widgets/team_crest.dart';
import 'club_page.dart';

class MatchDetailPage extends StatefulWidget {
  const MatchDetailPage({super.key, required this.match});

  final MatchModel match;

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  late Future<_VenueInfo> _venueFuture;
  bool _busy = false;

  MatchModel get match => widget.match;

  @override
  void initState() {
    super.initState();
    _venueFuture = _loadVenue();
  }

  String get _resultText {
    return switch (match.score.winner) {
      'HOME_TEAM' => '${match.homeTeam.shortName} menang',
      'AWAY_TEAM' => '${match.awayTeam.shortName} menang',
      'DRAW' => 'Seri',
      _ => '-',
    };
  }

  /// [UAS] Stadion tuan rumah -> koordinat -> cuaca saat kick-off.
  /// Bila lokasi pengguna tersedia, dihitung juga jarak dan cuaca di kotanya.
  Future<_VenueInfo> _loadVenue() async {
    final team = await FootballApiService.shared.fetchTeam(match.homeTeam.id);
    final coords =
        await LocationService.coordinatesOfAny(team.geocodeCandidates);

    WeatherForecast? stadiumFc;
    if (coords != null) {
      try {
        stadiumFc =
            await WeatherService.forecast(coords.latitude, coords.longitude);
      } catch (_) {}
    }

    final loc = AppSettings.instance.location;
    WeatherForecast? userFc;
    double? distance;
    if (loc != null) {
      try {
        userFc = await WeatherService.forecast(loc.latitude, loc.longitude);
      } catch (_) {}
      if (coords != null) {
        distance = LocationService.distanceKm(
          LatLon(loc.latitude, loc.longitude),
          coords,
        );
      }
    }

    return _VenueInfo(
      team: team,
      coords: coords,
      stadiumForecast: stadiumFc,
      userForecast: userFc,
      distanceKm: distance,
    );
  }

  Future<void> _toggleReminder() async {
    setState(() => _busy = true);
    final message = await ReminderService.toggle(match);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openClub(TeamModel team) {
    if (team.id == 0) return; // tim belum ditentukan
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClubPage(team: team)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = match.score;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Detail pertandingan')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Header(match: match, onTeamTap: _openClub),
          const SizedBox(height: 16),
          if (match.isUpcoming) _reminderButton(),
          SectionCard(
            title: 'Info pertandingan',
            icon: Icons.info_outline,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: [
                InfoRow('Pekan', 'Pekan ke-${match.matchday}'),
                InfoRow('Tanggal', dateFmt.format(match.kickoff)),
                InfoRow(
                  'Kick-off',
                  '${timeFmt.format(match.kickoff)} '
                      '(${DateTime.now().timeZoneName})',
                ),
                InfoRow('Status', match.statusLabel),
                InfoRow(
                  'Skor babak pertama',
                  s.hasHalfTime ? '${s.homeHalfTime} - ${s.awayHalfTime}' : '-',
                ),
                InfoRow(
                  'Skor akhir',
                  s.hasFullTime
                      ? '${s.homeFullTime} - ${s.awayFullTime}'
                      : 'Belum ada',
                ),
                InfoRow('Hasil', _resultText),
                InfoRow(
                  'Wasit',
                  match.referees.isEmpty
                      ? 'Belum diumumkan'
                      : match.referees.join(', '),
                  isLast: true,
                ),
              ],
            ),
          ),
          FutureBuilder<_VenueInfo>(
            future: _venueFuture,
            builder: (context, snap) => _venueCard(snap),
          ),
        ],
      ),
    );
  }

  Widget _reminderButton() {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        final active = settings.hasReminder(match.id);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: active
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleReminder,
                  icon: const Icon(Icons.notifications_active),
                  label: Text(
                    'Pengingat aktif (${settings.reminderMinutes} menit '
                    'sebelum) - ketuk untuk batal',
                  ),
                )
              : FilledButton.icon(
                  onPressed: _busy ? null : _toggleReminder,
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Ingatkan saya sebelum kick-off'),
                ),
        );
      },
    );
  }

  Widget _venueCard(AsyncSnapshot<_VenueInfo> snap) {
    final p = context.palette;
    const title = 'Stadion & cuaca';
    const icon = Icons.stadium;

    if (snap.connectionState != ConnectionState.done) {
      return const SectionCard(
        title: title,
        icon: icon,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (snap.hasError) {
      final e = snap.error;
      return SectionCard(
        title: title,
        icon: icon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e is ApiException ? e.message : 'Info stadion gagal dimuat.',
              style: TextStyle(color: p.muted),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _venueFuture = _loadVenue()),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final info = snap.data!;
    final kickoffUtc = match.kickoff.toUtc();
    final stadiumFc = info.stadiumForecast;
    final stadiumWeather = stadiumFc?.at(kickoffUtc);
    final userLoc = AppSettings.instance.location;
    final userWeather = info.userForecast?.at(kickoffUtc);
    final noForecastNote = Text(
      'Prakiraan cuaca baru tersedia sekitar 16 hari sebelum laga.',
      style: TextStyle(color: p.muted, fontSize: 12.5),
    );

    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.team.venue ?? 'Stadion ${info.team.team.shortName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (info.team.address != null)
            Text(info.team.address!, style: TextStyle(color: p.muted)),
          const SizedBox(height: 10),
          if (info.distanceKm != null)
            _iconLine(
              Icons.near_me_outlined,
              '± ${NumberFormat.decimalPattern('id_ID').format(info.distanceKm!.round())} km '
              'dari ${userLoc?.city ?? 'lokasimu'}',
            ),
          if (stadiumFc != null)
            _iconLine(
              Icons.schedule,
              'Kick-off waktu setempat: '
              '${DateFormat('HH:mm').format(stadiumFc.localTimeAt(kickoffUtc))} '
              '${stadiumFc.timezoneAbbreviation}',
            ),
          if (info.coords == null)
            _iconLine(
              Icons.location_off_outlined,
              'Lokasi stadion tidak ditemukan oleh geocoder perangkat.',
            ),
          const SizedBox(height: 12),
          if (info.coords != null) ...[
            if (stadiumWeather != null)
              WeatherSummary(
                point: stadiumWeather,
                caption: 'Cuaca di stadion saat kick-off',
              )
            else
              noForecastNote,
          ],
          if (userLoc != null && userWeather != null) ...[
            const SizedBox(height: 12),
            WeatherSummary(
              point: userWeather,
              caption: 'Cuaca di ${userLoc.city} saat kick-off',
            ),
            if (userWeather.kind.isWet)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Diperkirakan hujan di kotamu. Kalau mau nonton bareng di '
                  'luar, siapkan payung.',
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ),
          ],
          if (userLoc == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Aktifkan lokasi di tab "Saya" untuk melihat jarak dan '
                'cuaca di kotamu.',
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ),
          if (info.coords != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMaps(info.coords!),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Buka di Google Maps'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }

  Future<void> _openMaps(LatLon c) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${c.latitude},${c.longitude}',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka peta.')),
      );
    }
  }
}

class _VenueInfo {
  const _VenueInfo({
    required this.team,
    required this.coords,
    required this.stadiumForecast,
    required this.userForecast,
    required this.distanceKm,
  });

  final TeamDetail team;
  final LatLon? coords;
  final WeatherForecast? stadiumForecast;
  final WeatherForecast? userForecast;
  final double? distanceKm;
}

class _Header extends StatelessWidget {
  const _Header({required this.match, required this.onTeamTap});

  final MatchModel match;
  final ValueChanged<TeamModel> onTeamTap;

  @override
  Widget build(BuildContext context) {
    final s = match.score;
    final headline = s.hasFullTime
        ? '${s.homeFullTime} - ${s.awayFullTime}'
        : DateFormat('HH:mm').format(match.kickoff);

    return Container(
      color: AppColors.pitchDeep,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Row(
        children: [
          Expanded(
            child: _Side(
              team: match.homeTeam,
              onTap: () => onTeamTap(match.homeTeam),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                style: AppTheme.numeric(size: 44, color: Colors.white),
              ),
              const SizedBox(height: 6),
              StatusPill(match: match, onDark: true),
            ],
          ),
          Expanded(
            child: _Side(
              team: match.awayTeam,
              onTap: () => onTeamTap(match.awayTeam),
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.team, required this.onTap});

  final TeamModel team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: TeamCrest(url: team.crest, size: 56),
            ),
            const SizedBox(height: 10),
            Text(
              team.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Lihat profil',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
