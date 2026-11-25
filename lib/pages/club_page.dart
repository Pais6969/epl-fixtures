import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/match_model.dart';
import '../models/team_detail_model.dart';
import '../models/team_model.dart';
import '../services/football_api_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/match_card.dart';
import '../widgets/state_views.dart';
import '../widgets/team_crest.dart';
import 'match_detail_page.dart';

/// [UAS] Halaman baru: profil klub, jadwal klub, dan skuad.
class ClubPage extends StatefulWidget {
  const ClubPage({super.key, required this.team});

  /// Data dasar klub (dari jadwal/klasemen) agar judul langsung tampil.
  final TeamModel team;

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubData {
  const _ClubData(this.detail, this.fixtures);

  final TeamDetail detail;
  final FixturesData fixtures;
}

class _ClubPageState extends State<ClubPage> {
  final _api = FootballApiService.shared;
  late Future<_ClubData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ClubData> _load({bool force = false}) async {
    // Detail klub = 1 request (cache 1 hari). Jadwal memakai data musim
    // yang sama dengan tab Jadwal (sudah tersimpan di cache).
    final detail = await _api.fetchTeam(widget.team.id, force: force);
    final fixtures = await _api.fetchFixtures();
    return _ClubData(detail, fixtures);
  }

  void _reload() => setState(() => _future = _load(force: true));

  Future<void> _toggleFavorite() async {
    final settings = AppSettings.instance;
    final isFav = settings.favoriteTeamId == widget.team.id;
    await settings.setFavoriteTeam(isFav ? null : widget.team);
    ReminderService.resync().ignore();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(isFav
            ? '${widget.team.shortName} dihapus dari klub favorit.'
            : '${widget.team.shortName} jadi klub favoritmu. Laga-laganya '
                'akan diingatkan otomatis.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.shortName),
        actions: [
          ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) {
              final isFav =
                  AppSettings.instance.favoriteTeamId == widget.team.id;
              return IconButton(
                tooltip: isFav ? 'Hapus dari favorit' : 'Jadikan favorit',
                onPressed: _toggleFavorite,
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? AppColors.amber : null,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_ClubData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Memuat profil klub...');
          }
          if (snap.hasError) {
            final e = snap.error;
            return ErrorView(
              message: e is ApiException
                  ? e.message
                  : 'Terjadi kesalahan yang tidak terduga.',
              onRetry: _reload,
            );
          }
          return ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) => _content(snap.data!),
          );
        },
      ),
    );
  }

  Widget _content(_ClubData data) {
    final d = data.detail;
    final teamId = widget.team.id;
    final clubMatches = data.fixtures.matches
        .where((m) => m.homeTeam.id == teamId || m.awayTeam.id == teamId)
        .toList();
    final upcoming = clubMatches.where((m) => !m.isFinished).take(3).toList();
    final finished = clubMatches.where((m) => m.isFinished).toList();
    final recent = finished.reversed.take(5).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _ClubHeader(detail: d),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Info klub',
          icon: Icons.shield_outlined,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow('Stadion', d.venue ?? '-'),
              InfoRow('Alamat', d.address ?? '-'),
              InfoRow('Berdiri', d.founded?.toString() ?? '-'),
              InfoRow('Warna klub', d.clubColors ?? '-'),
              InfoRow(
                'Pelatih',
                d.coach == null
                    ? '-'
                    : '${d.coach!.name}'
                        '${d.coach!.nationality == null ? '' : ' (${d.coach!.nationality})'}',
                isLast: d.website == null,
              ),
              if (d.website != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(d.website!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Situs resmi'),
                  ),
                ),
            ],
          ),
        ),
        if (recent.isNotEmpty)
          SectionCard(
            title: 'Performa 5 laga terakhir',
            icon: Icons.trending_up,
            child: _FormRow(matches: recent, teamId: teamId),
          ),
        SectionCard(
          title: 'Laga berikutnya',
          icon: Icons.event_outlined,
          child: upcoming.isEmpty
              ? const Text('Tidak ada laga tersisa musim ini.')
              : Column(
                  children: [
                    for (final m in upcoming) _matchCard(m),
                  ],
                ),
        ),
        if (recent.isNotEmpty)
          SectionCard(
            title: 'Hasil terakhir',
            icon: Icons.history,
            child: Column(
              children: [
                for (final m in recent.take(3)) _matchCard(m),
              ],
            ),
          ),
        SectionCard(
          title: 'Skuad',
          icon: Icons.groups_outlined,
          child: _SquadList(squad: d.squad),
        ),
      ],
    );
  }

  Widget _matchCard(MatchModel m) {
    final s = AppSettings.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MatchCard(
        match: m,
        favoriteTeamId: s.favoriteTeamId,
        hasReminder: s.hasReminder(m.id),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailPage(match: m)),
        ),
      ),
    );
  }
}

class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.detail});

  final TeamDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pitchDeep,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: TeamCrest(url: detail.team.crest, size: 72),
          ),
          const SizedBox(height: 12),
          Text(
            detail.team.name,
            textAlign: TextAlign.center,
            style: AppTheme.numeric(size: 30, color: Colors.white),
          ),
          if (detail.venue != null)
            Text(
              detail.venue!,
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

/// Lima hasil terakhir: M (menang), S (seri), K (kalah).
class _FormRow extends StatelessWidget {
  const _FormRow({required this.matches, required this.teamId});

  final List<MatchModel> matches;
  final int teamId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    var won = 0;
    var draw = 0;
    var lost = 0;
    final chips = <Widget>[];
    // Ditampilkan dari laga terlama ke terbaru.
    for (final m in matches.reversed) {
      final isHome = m.homeTeam.id == teamId;
      final winner = m.score.winner;
      final String letter;
      final Color color;
      if (winner == 'DRAW' || winner == null) {
        letter = 'S';
        color = p.muted;
        draw++;
      } else if ((winner == 'HOME_TEAM') == isHome) {
        letter = 'M';
        color = AppColors.pitchBright;
        won++;
      } else {
        letter = 'K';
        color = AppColors.red;
        lost++;
      }
      chips.add(Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(right: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          letter,
          style: AppTheme.numeric(size: 20, color: Colors.white),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: chips),
        const SizedBox(height: 8),
        Text(
          '$won menang, $draw seri, $lost kalah (laga terbaru di kanan)',
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _SquadList extends StatelessWidget {
  const _SquadList({required this.squad});

  final List<PersonModel> squad;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (squad.isEmpty) {
      return Text(
        'Data skuad tidak tersedia pada paket gratis football-data.org.',
        style: TextStyle(color: p.muted),
      );
    }

    // Kelompokkan per posisi dengan urutan kiper -> penyerang.
    const order = ['Penjaga gawang', 'Bek', 'Gelandang', 'Penyerang'];
    final groups = <String, List<PersonModel>>{};
    for (final person in squad) {
      groups.putIfAbsent(person.positionLabel, () => []).add(person);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '$k (${groups[k]!.length})',
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
            ),
          ),
          for (final person in groups[k]!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      person.shirtNumber?.toString() ?? '-',
                      style: AppTheme.numeric(size: 18, color: p.muted),
                    ),
                  ),
                  Expanded(child: Text(person.name)),
                  Text(
                    [
                      ?person.nationality,
                      if (person.age != null) '${person.age} th',
                    ].join(' · '),
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
