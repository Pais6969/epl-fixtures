import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? Colors.white : p.accent),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.pitch,
      backgroundColor: p.surface,
      side: BorderSide(color: selected ? AppColors.pitch : p.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : p.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
