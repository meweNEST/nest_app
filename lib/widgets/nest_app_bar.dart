import 'package:flutter/material.dart';

class NestAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color backgroundColor;
  final double elevation;

  // Backwards-compatible with screens that pass these:
  final Widget? title;
  final double? toolbarHeight;
  final double? logoHeight;

  // Responsive base sizing:
  final double baseToolbarHeight;
  final double baseLogoHeight;

  const NestAppBar({
    super.key,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor = Colors.white,
    this.elevation = 0,
    this.title,
    this.toolbarHeight,
    this.logoHeight,
    this.baseToolbarHeight = 84,
    this.baseLogoHeight = 54,
  });

  double _clamp(double v, double min, double max) => v < min ? min : (v > max ? max : v);

  double _scaleForWidth(double w) {
    if (w < 360) return 0.92;
    if (w < 430) return 1.00;
    if (w < 600) return 1.08;
    return 1.18; // tablets
  }

  double _responsiveToolbarHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final s = _scaleForWidth(w);
    return _clamp(baseToolbarHeight * s, 76, 104);
  }

  double _responsiveLogoHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final s = _scaleForWidth(w);
    return _clamp(baseLogoHeight * s, 46, 74);
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? baseToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final double toolbarH = toolbarHeight ?? _responsiveToolbarHeight(context);
    final double logoH = logoHeight ?? _responsiveLogoHeight(context);

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      toolbarHeight: toolbarH,
      leading: leading,
      actions: actions,
      title: title ??
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Image.asset(
              'assets/images/nest_logo.png',
              height: logoH,
              fit: BoxFit.contain,
            ),
          ),
    );
  }
}
