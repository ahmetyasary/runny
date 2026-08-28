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
    return Image.asset(
      showWordmark ? AppAssets.logo : AppAssets.icon,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class RunnyMark extends StatelessWidget {
  const RunnyMark({
    super.key,
    this.size = 48,
    this.backgroundColor = AppColors.softGreen,
  });

  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Image.asset(
        AppAssets.icon,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
