import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../models/team_model.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';
import 'team_crest.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final MatchModel match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(child: _TeamSide(team: match.homeTeam)),
              SizedBox(width: 92, child: _Middle(match: match)),
              Expanded(child: _TeamSide(team: match.awayTeam)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamCrest(url: team.crest, size: 38),
        const SizedBox(height: 6),
        Text(
          team.shortName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _Middle extends StatelessWidget {
  const _Middle({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final s = match.score;
    final headline = s.hasFullTime
        ? '${s.homeFullTime} - ${s.awayFullTime}'
        : DateFormat('HH:mm').format(match.kickoff);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(headline, style: AppTheme.numeric(size: 28)),
        const SizedBox(height: 4),
        StatusPill(match: match),
      ],
    );
  }
}
