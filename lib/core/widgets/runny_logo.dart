import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

abstract final class AppAssets {
  static const logo = 'assets/branding/runny_logo.png';
  static const icon = 'assets/branding/runny_icon.png';
}

class RunnyLogo extends StatelessWidget {
  const RunnyLogo({
    super.key,
    this.height = 48,
    this.showWordmark = true,
  });

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      showWordmark ? AppAssets.logo : AppAssets.icon,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    // Logo koyu yeşil; dark modda okunabilir açık yeşile boya.
    if (!dark) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFF6BE08A),
        BlendMode.srcIn,
      ),
      child: image,
    );
  }
}

class RunnyMark extends StatelessWidget {
  const RunnyMark({
    super.key,
    this.size = 48,
    this.backgroundColor,
  });

  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = Image.asset(
      AppAssets.icon,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.softGreen,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: dark
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF6BE08A),
                BlendMode.srcIn,
              ),
              child: icon,
            )
          : icon,
    );
  }
}
