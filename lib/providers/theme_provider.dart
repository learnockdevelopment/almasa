import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _kDarkModeKey = 'theme_is_dark';

  bool _isDarkMode = true;
  String? _currentTheme;
  String? _currentThemeColor;

  bool get isDarkMode => _isDarkMode;
  String? get currentTheme => _currentTheme;
  String? get currentThemeColor => _currentThemeColor;

  ThemeData get themeData => _generateThemeData(_isDarkMode, _currentTheme, _currentThemeColor);
  ThemeData get lightThemeData => _generateThemeData(false, _currentTheme, _currentThemeColor);
  ThemeData get darkThemeData => _generateThemeData(true, _currentTheme, _currentThemeColor);

  // Restore saved preference; fall back to dark mode
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kDarkModeKey);
      if (saved != null) {
        _isDarkMode = saved == 'true';
      } else {
        // No saved preference — default to dark mode
        _isDarkMode = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDarkModeKey, _isDarkMode.toString());
    } catch (_) {}
  }

  void setTenant(String? themeName, {String? themeColor}) {
    if (_currentTheme != themeName || _currentThemeColor != themeColor) {
      _currentTheme = themeName;
      _currentThemeColor = themeColor;
      notifyListeners();
    }
  }

  static Color fromHSL(double h, double s, double l) {
    return HSLColor.fromAHSL(1.0, h, s / 100, l / 100).toColor();
  }

  static Color parseColorString(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.transparent;
    
    String clean = colorStr.trim().toLowerCase();
    
    if (clean.startsWith('hsl')) {
      try {
        final RegExp hslRegExp = RegExp(r'hsla?\s*\(\s*(\d+(?:\.\d+)?)\s*[, ]\s*(\d+(?:\.\d+)?)\s*%?\s*[, ]\s*(\d+(?:\.\d+)?)\s*%?\s*(?:[,/]\s*(\d+(?:\.\d+)?)\s*)?\)');
        final match = hslRegExp.firstMatch(clean);
        if (match != null) {
          double h = double.parse(match.group(1)!);
          double s = double.parse(match.group(2)!);
          double l = double.parse(match.group(3)!);
          double a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
          return HSLColor.fromAHSL(a, h, s / 100, l / 100).toColor();
        }
      } catch (_) {}
    }
    
    return hexToColor(colorStr);
  }

  static Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.transparent;
    try {
      final buffer = StringBuffer();
      String clean = hex.replaceFirst('#', '');
      if (clean.length == 6) buffer.write('ff');
      buffer.write(clean);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  ThemeData _generateThemeData(bool isDark, String? themeName, String? themeColorHex) {
    Color primary;
    if (themeColorHex != null && themeColorHex.isNotEmpty) {
      Color parsed = parseColorString(themeColorHex);
      if (parsed != Colors.transparent) {
        primary = parsed;
      } else {
        primary = isDark ? fromHSL(230, 85, 60) : fromHSL(225, 80, 55);
      }
    } else {
      primary = isDark ? fromHSL(230, 85, 60) : fromHSL(225, 80, 55);
    }

    Color scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white; // Slate 900
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white; // Slate 800
    Color divider = isDark ? const Color(0xFF334155) : fromHSL(214, 32, 91); // Slate 700

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      dividerColor: divider,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              surface: cardColor,
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white.withOpacity(0.6),
            )
          : ColorScheme.light(
              primary: primary,
              surface: cardColor,
              onSurface: Colors.black,
              onSurfaceVariant: const Color(0xFF475569),
            ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900),
        titleLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }
}
