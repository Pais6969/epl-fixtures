import 'package:flutter/material.dart';

import '../models/match_model.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.match, this.onDark = false});

  final MatchModel match;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    if (onDark) {
      fg = Colors.white;
      bg = Colors.white.withAlpha(36);
    } else if (match.isLive) {
      fg = AppColors.amber;
      bg = AppColors.amber.withAlpha(40);
    } else if (match.isFinished) {
      fg = AppColors.muted;
      bg = AppColors.ink.withAlpha(14);
    } else {
      fg = AppColors.pitch;
      bg = AppColors.pitch.withAlpha(26);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        match.statusLabel,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
