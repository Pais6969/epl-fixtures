import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../models/team_model.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import '../widgets/team_crest.dart';

class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({super.key, required this.match});

  final MatchModel match;

  String get _resultText {
    return switch (match.score.winner) {
      'HOME_TEAM' => '${match.homeTeam.shortName} menang',
      'AWAY_TEAM' => '${match.awayTeam.shortName} menang',
      'DRAW' => 'Seri',
      _ => '-',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = match.score;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Detail pertandingan')),
      body: ListView(
        children: [
          _Header(match: match),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                _InfoRow('Pekan', 'Pekan ke-${match.matchday}'),
                _InfoRow('Tanggal', dateFmt.format(match.kickoff)),
                _InfoRow('Kick-off', '${timeFmt.format(match.kickoff)} '
                    '(waktu perangkat)'),
                _InfoRow('Status', match.statusLabel),
                _InfoRow(
                  'Skor babak pertama',
                  s.hasHalfTime ? '${s.homeHalfTime} - ${s.awayHalfTime}' : '-',
                ),
                _InfoRow(
                  'Skor akhir',
                  s.hasFullTime
                      ? '${s.homeFullTime} - ${s.awayFullTime}'
                      : 'Belum ada',
                ),
                _InfoRow('Hasil', _resultText),
                _InfoRow(
                  'Wasit',
                  match.referees.isEmpty
                      ? 'Belum diumumkan'
                      : match.referees.join(', '),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.match});

  final MatchModel match;

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
          Expanded(child: _Side(team: match.homeTeam)),
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
          Expanded(child: _Side(team: match.awayTeam)),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    return Column(
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
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
