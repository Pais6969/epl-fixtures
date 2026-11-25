import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weather_model.dart';
import '../services/football_api_service.dart';
import '../theme/app_theme.dart';

/// [UAS] Kartu berjudul untuk mengelompokkan informasi.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Baris "label ........ nilai".
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(color: p.muted)),
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

/// [UAS] Pita kuning yang muncul saat data berasal dari cache (offline).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: FootballApiService.shared.offlineSince,
      builder: (context, since, _) {
        if (since == null) return const SizedBox.shrink();
        final when = DateFormat('d MMM, HH:mm', 'id_ID').format(since);
        return Container(
          width: double.infinity,
          color: AppColors.amber.withAlpha(46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mode offline - menampilkan data tersimpan ($when).',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// [UAS] Ringkasan cuaca: ikon, kondisi, suhu, dan peluang hujan.
class WeatherSummary extends StatelessWidget {
  const WeatherSummary({super.key, required this.point, this.caption});

  final WeatherPoint point;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final kind = point.kind;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kind.color.withAlpha(36),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(kind.icon, color: kind.color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null)
                Text(caption!, style: TextStyle(color: p.muted, fontSize: 12)),
              Text(
                kind.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (point.precipitationChance != null)
                Text(
                  'Peluang hujan ${point.precipitationChance}%',
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        Text(
          '${point.temperature.round()}°C',
          style: AppTheme.numeric(size: 28),
        ),
      ],
    );
  }
}
