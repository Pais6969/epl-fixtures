import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Logo klub. API memberi logo dalam format PNG atau SVG, keduanya ditangani.
class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, required this.url, this.size = 32});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Icon(
          Icons.shield_outlined,
          size: size * 0.8,
          color: context.palette.muted,
        );

    final Widget child;
    if (url.isEmpty) {
      child = fallback();
    } else if (url.toLowerCase().endsWith('.svg')) {
      child = SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    } else {
      child = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }
    return SizedBox(width: size, height: size, child: child);
  }
}
