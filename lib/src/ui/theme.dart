import 'package:flutter/material.dart';

/// Visual language of the app: Material 3 with Google Sans, the neutral
/// surfaces Google uses in its AI products and their blue-violet-rose
/// accent gradient.
abstract final class AppTheme {
  static const fontFamily = 'Google Sans';

  /// Accent gradient stops, blue to violet to rose.
  static const gradientColors = [
    Color(0xFF4285F4),
    Color(0xFF9B72CB),
    Color(0xFFD96570),
  ];

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: gradientColors,
  );

  static ThemeData light() => _build(_lightScheme);

  static ThemeData dark() => _build(_darkScheme);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0B57D0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD3E3FD),
    onPrimaryContainer: Color(0xFF041E49),
    secondary: Color(0xFF00639B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFC2E7FF),
    onSecondaryContainer: Color(0xFF001D35),
    tertiary: Color(0xFF7B5AA6),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF0DBFF),
    onTertiaryContainer: Color(0xFF2C0B51),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1F1F1F),
    onSurfaceVariant: Color(0xFF444746),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8FAFD),
    surfaceContainer: Color(0xFFF0F4F9),
    surfaceContainerHigh: Color(0xFFE9EEF6),
    surfaceContainerHighest: Color(0xFFDDE3EA),
    outline: Color(0xFF747775),
    outlineVariant: Color(0xFFC4C7C5),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFF2F2F2),
    inversePrimary: Color(0xFFA8C7FA),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA8C7FA),
    onPrimary: Color(0xFF062E6F),
    primaryContainer: Color(0xFF0842A0),
    onPrimaryContainer: Color(0xFFD3E3FD),
    secondary: Color(0xFF7FCFFF),
    onSecondary: Color(0xFF003355),
    secondaryContainer: Color(0xFF004A77),
    onSecondaryContainer: Color(0xFFC2E7FF),
    tertiary: Color(0xFFD7BAFF),
    onTertiary: Color(0xFF42206D),
    tertiaryContainer: Color(0xFF5A3985),
    onTertiaryContainer: Color(0xFFF0DBFF),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF131314),
    onSurface: Color(0xFFE3E3E3),
    onSurfaceVariant: Color(0xFFC4C7C5),
    surfaceContainerLowest: Color(0xFF0E0E0F),
    surfaceContainerLow: Color(0xFF1B1B1C),
    surfaceContainer: Color(0xFF1E1F20),
    surfaceContainerHigh: Color(0xFF282A2C),
    surfaceContainerHighest: Color(0xFF333537),
    outline: Color(0xFF8E918F),
    outlineVariant: Color(0xFF444746),
    inverseSurface: Color(0xFFE3E3E3),
    onInverseSurface: Color(0xFF303030),
    inversePrimary: Color(0xFF0B57D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData _build(ColorScheme colors) {
    final base = ThemeData(colorScheme: colors, fontFamily: fontFamily);
    const pill = StadiumBorder();
    final shortRadius = BorderRadius.circular(16);

    return base.copyWith(
      textTheme: _withVariableWeights(base.textTheme),
      scaffoldBackgroundColor: colors.surface,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          minimumSize: const Size(48, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: pill),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: shortRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: shortRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: shortRadius,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: shortRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 420,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: colors.onInverseSurface,
          fontSize: 12,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 8 : 4,
        ),
      ),
    );
  }

  /// Google Sans ships as a variable font; bind each style's weight to the
  /// font's `wght` axis so weights render exactly.
  static TextTheme _withVariableWeights(TextTheme theme) {
    TextStyle? apply(TextStyle? style) =>
        style?.withWeight(style.fontWeight ?? FontWeight.w400);

    return theme.copyWith(
      displayLarge: apply(theme.displayLarge),
      displayMedium: apply(theme.displayMedium),
      displaySmall: apply(theme.displaySmall),
      headlineLarge: apply(theme.headlineLarge),
      headlineMedium: apply(theme.headlineMedium),
      headlineSmall: apply(theme.headlineSmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      labelLarge: apply(theme.labelLarge),
      labelMedium: apply(theme.labelMedium),
      labelSmall: apply(theme.labelSmall),
    );
  }
}

extension VariableWeight on TextStyle {
  /// Sets [weight] both as the font weight and on the variable font's
  /// `wght` axis.
  TextStyle withWeight(FontWeight weight) => copyWith(
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
  );
}

/// Material 3 motion tokens used across the app.
abstract final class Motion {
  static const short = Durations.short4;
  static const medium = Durations.medium2;
  static const long = Durations.medium4;
  static const emphasized = Easing.emphasizedDecelerate;
  static const standard = Easing.standard;
}

/// Paints [child] (typically text) with the accent gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: AppTheme.gradient.createShader,
    child: Text(text, style: style),
  );
}
