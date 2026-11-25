import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../models/team_model.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';
import 'team_crest.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.favoriteTeamId,
    this.hasReminder = false,
  });

  final MatchModel match;
  final VoidCallback onTap;

  /// [UAS] Kartu diberi tanda bila melibatkan klub favorit.
  final int? favoriteTeamId;

  /// [UAS] Ikon lonceng tampil bila pengingat sudah dipasang.
  final bool hasReminder;

  bool get _isFavorite =>
      favoriteTeamId != null &&
      (match.homeTeam.id == favoriteTeamId ||
          match.awayTeam.id == favoriteTeamId);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(14);

    return Material(
      color: p.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: _isFavorite ? AppColors.amber : p.line,
          width: _isFavorite ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: _TeamSide(team: match.homeTeam)),
                  SizedBox(width: 92, child: _Middle(match: match)),
                  Expanded(child: _TeamSide(team: match.awayTeam)),
                ],
              ),
            ),
            if (_isFavorite || hasReminder)
              Positioned(
                top: 6,
                right: 8,
                child: Row(
                  children: [
                    if (_isFavorite)
                      const Icon(Icons.star, size: 16, color: AppColors.amber),
                    if (hasReminder)
                      Icon(Icons.notifications_active,
                          size: 16, color: p.accent),
                  ],
                ),
              ),
          ],
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
