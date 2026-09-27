import 'package:flutter/material.dart';

/// sourcecrush is deliberately monochrome: a black canvas, white type and
/// greys in between. There is no accent hue anywhere in the app, so the only
/// thing colour ever communicates is emphasis.
abstract final class SC {
  /// Pure black canvas.
  static const background = Color(0xFF000000);

  /// Raised surfaces: pills, cards, inputs.
  static const surface = Color(0xFF0D0D0D);
  static const surfaceHigh = Color(0xFF161616);

  /// Hairlines and pill borders.
  static const outline = Color(0x1AFFFFFF);

  /// Type ramp, strongest first.
  static const text = Colors.white;
  static const textMuted = Color(0x99FFFFFF);
  static const textFaint = Color(0x61FFFFFF);
  static const textGhost = Color(0x3DFFFFFF);

  /// Placeholder art: a soft grey wash rather than a coloured gradient.
  static const artworkTop = Color(0xFF3C3C3C);
  static const artworkBottom = Color(0xFF141414);

  static const artworkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [artworkTop, artworkBottom],
  );
}

/// The app-wide dark theme.
///
/// Type is the platform's own UI font. No `fontFamily` is set anywhere in the
/// app, so Flutter resolves to the system face (Roboto on Android) and picks up
/// the user's font scale and weight settings for free. The only bundled fonts
/// are Material's icon font, which is not text.
ThemeData buildSourcecrushTheme() {
  const scheme = ColorScheme.dark(
    primary: Colors.white,
    onPrimary: Colors.black,
    secondary: Colors.white,
    onSecondary: Colors.black,
    surface: SC.surface,
    onSurface: Colors.white,
    onSurfaceVariant: SC.textMuted,
    outline: SC.outline,
    // Kept monochrome on purpose; if destructive states ever need to shout,
    // this is the one place a hue would be justified.
    error: Colors.white,
    onError: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SC.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: SC.text, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: SC.text, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: SC.textMuted),
      labelSmall: TextStyle(color: SC.textFaint, letterSpacing: 1.6),
    ),
  );
}
