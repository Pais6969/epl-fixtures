import 'package:flutter/material.dart';

import '../models/scorer_model.dart';
import '../models/standing_model.dart';
import '../models/team_model.dart';
import '../services/football_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/team_crest.dart';
import 'club_page.dart';

/// [UAS] Halaman baru: Top Skor (dari API) dan Statistik Klub
/// (diolah dari data klasemen).
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.service});

  final FootballApiService service;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<List<ScorerModel>> _scorers;
  late Future<List<StandingRow>> _standings;

  @override
  void initState() {
    super.initState();
    _scorers = widget.service.fetchScorers();
    _standings = widget.service.fetchStandings();
  }

  void _reload() {
    setState(() {
      _scorers = widget.service.fetchScorers(force: true);
      _standings = widget.service.fetchStandings(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistik'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Top Skor'),
              Tab(text: 'Statistik Klub'),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _ScorersTab(future: _scorers, onRetry: _reload),
                  _TeamStatsTab(future: _standings, onRetry: _reload),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openClub(BuildContext context, TeamModel team) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ClubPage(team: team)),
  );
}

class _ScorersTab extends StatelessWidget {
  const _ScorersTab({required this.future, required this.onRetry});

  final Future<List<ScorerModel>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<ScorerModel>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Memuat pencetak gol...');
        }
        if (snap.hasError) {
          final e = snap.error;
          // Data top skor bisa jadi tidak termasuk paket gratis API.
          if (e is ApiException && e.isRestricted) {
            return const EmptyView(
              icon: Icons.lock_outline,
              message: 'Data pencetak gol tidak tersedia pada paket gratis '
                  'football-data.org.\nLihat tab "Statistik Klub" untuk '
                  'statistik yang diolah dari klasemen.',
            );
          }
          return ErrorView(
            message: e is ApiException
                ? e.message
                : 'Terjadi kesalahan yang tidak terduga.',
            onRetry: onRetry,
          );
        }
        final scorers = snap.data!;
        if (scorers.isEmpty) {
          return const EmptyView(message: 'Belum ada data pencetak gol.');
        }
        final maxGoals = scorers.first.goals == 0 ? 1 : scorers.first.goals;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: scorers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = scorers[i];
            return Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: p.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openClub(context, s.team),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text('${i + 1}', style: AppTheme.numeric(size: 22)),
                      ),
                      TeamCrest(url: s.team.crest, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.playerName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              [
                                s.team.shortName,
                                if (s.assists != null) '${s.assists} assist',
                                if (s.penalties != null && s.penalties! > 0)
                                  '${s.penalties} penalti',
                              ].join(' · '),
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            _Bar(fraction: s.goals / maxGoals),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          Text('${s.goals}', style: AppTheme.numeric(size: 28)),
                          Text('gol',
                              style: TextStyle(color: p.muted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamStatsTab extends StatelessWidget {
  const _TeamStatsTab({required this.future, required this.onRetry});

  final Future<List<StandingRow>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StandingRow>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Mengolah statistik klub...');
        }
        if (snap.hasError) {
          final e = snap.error;
          return ErrorView(
            message: e is ApiException
                ? e.message
                : 'Terjadi kesalahan yang tidak terduga.',
            onRetry: onRetry,
          );
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return const EmptyView(message: 'Belum ada data klasemen.');
        }

        double perGame(StandingRow r, int value) =>
            r.playedGames == 0 ? 0 : value / r.playedGames;

        final attack = [...rows]
          ..sort((a, b) => b.goalsFor.compareTo(a.goalsFor));
        final defence = [...rows]
          ..sort((a, b) => a.goalsAgainst.compareTo(b.goalsAgainst));
        final ppg = [...rows]
          ..sort((a, b) =>
              perGame(b, b.points).compareTo(perGame(a, a.points)));
        final wins = [...rows]..sort((a, b) => b.won.compareTo(a.won));

        final totalGoals = rows.fold<int>(0, (sum, r) => sum + r.goalsFor);
        // Setiap laga dihitung dua kali (sekali per tim).
        final totalGames =
            rows.fold<int>(0, (sum, r) => sum + r.playedGames) ~/ 2;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _SummaryRow(totalGoals: totalGoals, totalGames: totalGames),
            _RankCard(
              title: 'Lini serang terbaik',
              subtitle: 'Gol yang dicetak',
              icon: Icons.sports_soccer,
              rows: attack.take(5).toList(),
              value: (r) => r.goalsFor.toDouble(),
              label: (r) => '${r.goalsFor}',
            ),
            _RankCard(
              title: 'Pertahanan terbaik',
              subtitle: 'Gol kebobolan paling sedikit',
              icon: Icons.shield_outlined,
              rows: defence.take(5).toList(),
              // Batang lebih panjang = kebobolan lebih sedikit.
              value: (r) => 1 / (r.goalsAgainst + 1),
              label: (r) => '${r.goalsAgainst}',
            ),
            _RankCard(
              title: 'Rata-rata poin per laga',
              subtitle: 'Poin dibagi jumlah main',
              icon: Icons.speed,
              rows: ppg.take(5).toList(),
              value: (r) => perGame(r, r.points),
              label: (r) => perGame(r, r.points).toStringAsFixed(2),
            ),
            _RankCard(
              title: 'Kemenangan terbanyak',
              subtitle: 'Jumlah menang',
              icon: Icons.emoji_events_outlined,
              rows: wins.take(5).toList(),
              value: (r) => r.won.toDouble(),
              label: (r) => '${r.won}',
            ),
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.totalGoals, required this.totalGames});

  final int totalGoals;
  final int totalGames;

  @override
  Widget build(BuildContext context) {
    final avg = totalGames == 0 ? 0 : totalGoals / totalGames;
    Widget tile(String value, String label) {
      final p = context.palette;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              Text(value, style: AppTheme.numeric(size: 30, color: p.accent)),
              Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          tile('$totalGames', 'Laga dimainkan'),
          const SizedBox(width: 10),
          tile('$totalGoals', 'Total gol'),
          const SizedBox(width: 10),
          tile(avg.toStringAsFixed(2), 'Gol per laga'),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rows,
    required this.value,
    required this.label,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<StandingRow> rows;
  final double Function(StandingRow) value;
  final String Function(StandingRow) label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = rows
        .map(value)
        .fold<double>(0, (m, v) => v > m ? v : m);

    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12)),
          const SizedBox(height: 8),
          for (final r in rows)
            InkWell(
              onTap: () => _openClub(context, r.team),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    TeamCrest(url: r.team.crest, size: 22),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        r.team.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: _Bar(
                        fraction: maxValue == 0 ? 0 : value(r) / maxValue,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        label(r),
                        textAlign: TextAlign.end,
                        style: AppTheme.numeric(size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grafik batang horizontal sederhana.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, box) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Container(height: 8, width: box.maxWidth, color: p.line),
            Container(
              height: 8,
              width: box.maxWidth * fraction.clamp(0.02, 1.0),
              color: p.accent,
            ),
          ],
        ),
      ),
    );
  }
}
