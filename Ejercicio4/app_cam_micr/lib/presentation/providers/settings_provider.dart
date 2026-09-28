import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs)
      : _palette = AppPalette.values.asNameMap()[_prefs.getString(_kPalette)] ?? AppPalette.guinda,
        _themeMode = ThemeMode.values.asNameMap()[_prefs.getString(_kMode)] ?? ThemeMode.system,
        _saveLocation = _prefs.getBool(_kLocation) ?? true;

  static const _kPalette = 'palette';
  static const _kMode = 'theme_mode';
  static const _kLocation = 'save_location';

  final SharedPreferences _prefs;
  AppPalette _palette;
  ThemeMode _themeMode;
  bool _saveLocation;

  AppPalette get palette => _palette;
  ThemeMode get themeMode => _themeMode;
  bool get saveLocation => _saveLocation;

  Future<void> setPalette(AppPalette value) async {
    _palette = value;
    notifyListeners();
    await _prefs.setString(_kPalette, value.name);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    await _prefs.setString(_kMode, value.name);
  }

  Future<void> setSaveLocation(bool value) async {
    _saveLocation = value;
    notifyListeners();
    await _prefs.setBool(_kLocation, value);
  }
}
