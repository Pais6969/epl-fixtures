import 'package:flutter/material.dart';

import '../models/standing_model.dart';
import '../services/football_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/team_crest.dart';

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
      _future = widget.service.fetchStandings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasemen Premier League'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<StandingRow>>(
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
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    const _HeaderRow(),
                    for (final r in rows) _StandingTile(row: r, total: rows.length),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          );
        },
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
    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    Widget cell(String text, double width) => SizedBox(
          width: width,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );

    return Container(
      color: AppColors.chalk,
      padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
      child: Row(
        children: [
          cell('#', 28),
          const Expanded(child: Text('Klub', style: style)),
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
  const _StandingTile({required this.row, required this.total});

  final StandingRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    // Penanda zona: 4 besar (Liga Champions) dan 3 terbawah (degradasi).
    final Color zone = row.position <= 4
        ? AppColors.pitch
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

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
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
                          Expanded(
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
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(AppColors.pitch, '4 besar'),
        item(AppColors.red, 'Zona degradasi'),
        const Text(
          'Main, M = menang, S = seri, K = kalah, SG = selisih gol',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
