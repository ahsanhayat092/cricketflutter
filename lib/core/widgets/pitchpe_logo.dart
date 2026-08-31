import 'package:flutter/material.dart';

enum PitchPeLogoVariant {
  /// Primary horizontal lockup (Icon + PitchPe Wordmark)
  primary,

  /// Compact horizontal lockup (Optimized for App Bar / Header)
  compact,

  /// Standalone green cricket-pitch P-icon
  iconOnly,

  /// White monochrome icon for high-contrast dark surfaces
  monochrome,

  /// Official App Icon with dark squircle background
  appIcon,
}

enum PitchPeLogoTheme {
  /// Automatically picks light/dark based on current Theme brightness
  auto,

  /// Force light mode (Green Icon + Dark Wordmark)
  light,

  /// Force dark mode (Green Icon + White Wordmark)
  dark,
}

/// The official PitchPe Branding Component.
/// Adheres strictly to the official PitchPe Brand Asset Sheet.
class PitchPeLogo extends StatelessWidget {
  final PitchPeLogoVariant variant;
  final PitchPeLogoTheme theme;
  final double? height;
  final double? width;
  final BoxFit fit;

  const PitchPeLogo({
    super.key,
    this.variant = PitchPeLogoVariant.primary,
    this.theme = PitchPeLogoTheme.auto,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  /// Convenience constructor for compact header logo
  const PitchPeLogo.compact({
    super.key,
    this.theme = PitchPeLogoTheme.auto,
    this.height = 32,
    this.width,
    this.fit = BoxFit.contain,
  }) : variant = PitchPeLogoVariant.compact;

  /// Convenience constructor for standalone icon
  const PitchPeLogo.icon({
    super.key,
    this.theme = PitchPeLogoTheme.auto,
    this.height = 36,
    this.width,
    this.fit = BoxFit.contain,
  }) : variant = PitchPeLogoVariant.iconOnly;

  /// Convenience constructor for app icon squircle
  const PitchPeLogo.appIcon({
    super.key,
    this.height = 48,
    this.width,
    this.fit = BoxFit.contain,
  })  : variant = PitchPeLogoVariant.appIcon,
        theme = PitchPeLogoTheme.dark;

  /// Convenience constructor for white monochrome icon
  const PitchPeLogo.monochrome({
    super.key,
    this.height = 36,
    this.width,
    this.fit = BoxFit.contain,
  })  : variant = PitchPeLogoVariant.monochrome,
        theme = PitchPeLogoTheme.dark;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _resolveIsDarkMode(context);
    final assetPath = _getAssetPath(isDarkMode);

    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback in case asset loading fails
        return SizedBox(
          height: height ?? 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: height ?? 32,
                height: height ?? 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'P',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              if (variant != PitchPeLogoVariant.iconOnly &&
                  variant != PitchPeLogoVariant.appIcon &&
                  variant != PitchPeLogoVariant.monochrome) ...[
                const SizedBox(width: 8),
                Text(
                  'PitchPe',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _resolveIsDarkMode(BuildContext context) {
    switch (theme) {
      case PitchPeLogoTheme.light:
        return false;
      case PitchPeLogoTheme.dark:
        return true;
      case PitchPeLogoTheme.auto:
        return Theme.of(context).brightness == Brightness.dark;
    }
  }

  String _getAssetPath(bool isDarkMode) {
    switch (variant) {
      case PitchPeLogoVariant.appIcon:
        return 'assets/images/pitchpe_app_icon.png';
      case PitchPeLogoVariant.iconOnly:
        return 'assets/images/pitchpe_icon_green.png';
      case PitchPeLogoVariant.monochrome:
        return 'assets/images/pitchpe_icon_white.png';
      case PitchPeLogoVariant.compact:
        return isDarkMode
            ? 'assets/images/pitchpe_logo_dark.png'
            : 'assets/images/pitchpe_compact_light.png';
      case PitchPeLogoVariant.primary:
        return isDarkMode
            ? 'assets/images/pitchpe_logo_dark.png'
            : 'assets/images/pitchpe_logo_light.png';
    }
  }
}
