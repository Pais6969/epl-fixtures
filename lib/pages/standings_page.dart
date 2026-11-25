import 'package:flutter/material.dart';

import '../models/standing_model.dart';
import '../services/football_api_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/team_crest.dart';
import 'club_page.dart';
import 'search_page.dart';

// Warna penanda zona klasemen.
const Color _zoneChampionsLeague = AppColors.blue; // biru
const Color _zoneEuropaLeague = AppColors.orange; // oranye

class StandingsPage extends StatefulWidget {
  const StandingsPage({super.key, required this.service});

  final FootballApiService service;

  @override
  State<StandingsPage> createState() => _StandingsPageState();
}

class _StandingsPageState extends State<StandingsPage> {
  late Future<List<StandingRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchStandings();
  }

  void _reload() {
    setState(() {
      _future = widget.service.fetchStandings(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasemen Premier League'),
        actions: [
          IconButton(
            tooltip: 'Cari klub',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: FutureBuilder<List<StandingRow>>(
              future: _future,
              builder: (context, snapshot) {
                // 1. Loading
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Memuat klasemen...');
                }
                // 2. Error
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return ErrorView(
                    message: error is ApiException
                        ? error.message
                        : 'Terjadi kesalahan yang tidak terduga.',
                    onRetry: _reload,
                  );
                }
                // 3. Success
                final rows = snapshot.data!;
                return ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) {
                    final favId = AppSettings.instance.favoriteTeamId;
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.line),
                          ),
                          child: Column(
                            children: [
                              const _HeaderRow(),
                              for (final r in rows)
                                _StandingTile(
                                  row: r,
                                  total: rows.length,
                                  isFavorite: r.team.id == favId,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ClubPage(team: r.team),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _Legend(),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Lebar kolom angka (dipakai bersama oleh header dan baris).
const double _wNum = 28;
const double _wGd = 34;
const double _wPts = 40;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(
      color: p.muted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    Widget cell(String text, double width) => SizedBox(
          width: width,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );

    return Container(
      color: p.background,
      padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
      child: Row(
        children: [
          cell('#', 28),
          Expanded(child: Text('Klub', style: style)),
          cell('Main', 34),
          cell('M', _wNum),
          cell('S', _wNum),
          cell('K', _wNum),
          cell('SG', _wGd),
          cell('Poin', _wPts),
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({
    required this.row,
    required this.total,
    required this.isFavorite,
    required this.onTap,
  });

  final StandingRow row;
  final int total;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Penanda zona:
    // 1-4  : Liga Champions (biru)
    // 5-7  : Europa League (oranye)
    // 3 terbawah : degradasi (merah)
    final Color zone = row.position <= 4
        ? _zoneChampionsLeague
        : row.position <= 7
            ? _zoneEuropaLeague
            : row.position > total - 3
                ? AppColors.red
                : Colors.transparent;

    Widget cell(String text, double width, {bool bold = false}) => SizedBox(
          width: width,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: bold
                ? AppTheme.numeric(size: 18)
                : AppTheme.numeric(size: 16, weight: FontWeight.w500),
          ),
        );

    final gd = row.goalDifference > 0
        ? '+${row.goalDifference}'
        : '${row.goalDifference}';

    return Material(
      // [UAS] Klub favorit diberi latar kuning tipis.
      color: isFavorite ? AppColors.amber.withAlpha(30) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: zone),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                    child: Row(
                      children: [
                        cell('${row.position}', 28, bold: true),
                        Expanded(
                          child: Row(
                            children: [
                              TeamCrest(url: row.team.crest, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  row.team.shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.star,
                                      size: 14, color: AppColors.amber),
                                ),
                            ],
                          ),
                        ),
                        cell('${row.playedGames}', 34),
                        cell('${row.won}', _wNum),
                        cell('${row.draw}', _wNum),
                        cell('${row.lost}', _wNum),
                        cell(gd, _wGd),
                        cell('${row.points}', _wPts, bold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: p.muted, fontSize: 12)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(_zoneChampionsLeague, 'Liga Champions'),
        item(_zoneEuropaLeague, 'Europa League'),
        item(AppColors.red, 'Zona degradasi'),
        Text(
          'Main, M = menang, S = seri, K = kalah, SG = selisih gol. '
          'Ketuk klub untuk melihat profilnya.',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    );
  }
}
