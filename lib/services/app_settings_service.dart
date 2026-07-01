import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _isSetupCompleteKey = 'isSetupComplete';
  static const String _selectedLanguagesKey = 'flutter.selected_languages';
  static const String _showPeriodButtonKey = 'show_period_button';
  static const String _floatingMicEnabledKey = 'floating_mic_enabled';

  Future<void> setFloatingMicEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingMicEnabledKey, value);
  }

  Future<bool> getFloatingMicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingMicEnabledKey) ?? false;
  }

  static const List<Map<String, String>> availableLanguages = [
    {'name': 'English (US)', 'code': 'en_US'},
    {'name': 'Chinese (Simplified)', 'code': 'zh_CN'},
    {'name': 'Chinese (Traditional)', 'code': 'zh_TW'},
    {'name': 'Spanish', 'code': 'es_ES'},
    {'name': 'French', 'code': 'fr_FR'},
    {'name': 'German', 'code': 'de_DE'},
    {'name': 'Japanese', 'code': 'ja_JP'},
    {'name': 'Korean', 'code': 'ko_KR'},
    {'name': 'Russian', 'code': 'ru_RU'},
    {'name': 'Portuguese', 'code': 'pt_PT'},
  ];

  Future<void> resetSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isSetupCompleteKey);
  }

  Future<List<String>> getSelectedLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_selectedLanguagesKey) ?? ['en_US'];
  }

  Future<void> setSelectedLanguages(List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedLanguagesKey, codes);
  }

  Future<bool> getShowPeriodButton() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showPeriodButtonKey) ?? true;
  }

  Future<void> setShowPeriodButton(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPeriodButtonKey, value);
  }

  Future<String> getSelectedLanguageNames() async {
    final selectedCodes = await getSelectedLanguages();
    final names = <String>[];
    for (final code in selectedCodes) {
      final lang = availableLanguages.firstWhere(
        (l) => l['code'] == code,
        orElse: () => {'name': code, 'code': code},
      );
      names.add(lang['name']!);
    }
    return names.join(', ');
  }

  static const String _floatingMicColorKey = 'floating_mic_color';
  static const String _floatingMicIconColorKey = 'floating_mic_icon_color';
  static const String _floatingMicSizeKey = 'floating_mic_size';
  static const String _floatingMicIconKey = 'floating_mic_icon';

  Future<String> getFloatingMicColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_floatingMicColorKey) ?? 'theme';
  }

  Future<void> setFloatingMicColor(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_floatingMicColorKey, value);
  }

  Future<String> getFloatingMicIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_floatingMicIconColorKey) ?? '#FFFFFF';
  }

  Future<void> setFloatingMicIconColor(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_floatingMicIconColorKey, value);
  }

  Future<String> getFloatingMicSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_floatingMicSizeKey) ?? 'medium';
  }

  Future<void> setFloatingMicSize(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_floatingMicSizeKey, value);
  }

  Future<String> getFloatingMicIcon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_floatingMicIconKey) ?? 'mic';
  }

  Future<void> setFloatingMicIcon(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_floatingMicIconKey, value);
  }

  static const String _floatingMicMutedUntilKey = 'floating_mic_muted_until';

  Future<int> getFloatingMicMutedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_floatingMicMutedUntilKey) ?? 0;
  }

  Future<void> clearFloatingMicMuted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_floatingMicMutedUntilKey);
  }

  static const String _floatingMicShowingKey = 'floating_mic_showing';

  Future<bool> getFloatingMicShowing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingMicShowingKey) ?? false;
  }

  Future<void> setFloatingMicShowing(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingMicShowingKey, value);
  }

  static const String _floatingMicAutoFoldKey = 'floating_mic_auto_fold';

  Future<bool> getFloatingMicAutoFold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingMicAutoFoldKey) ?? false;
  }

  Future<void> setFloatingMicAutoFold(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingMicAutoFoldKey, value);
  }

  static const String _floatingMicHideInLandscapeKey = 'floating_mic_hide_in_landscape';

  Future<bool> getFloatingMicHideInLandscape() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingMicHideInLandscapeKey) ?? true;
  }

  Future<void> setFloatingMicHideInLandscape(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingMicHideInLandscapeKey, value);
  }

  static const String _floatingMicHideInGamesKey = 'floating_mic_hide_in_games';

  Future<bool> getFloatingMicHideInGames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingMicHideInGamesKey) ?? true;
  }

  Future<void> setFloatingMicHideInGames(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingMicHideInGamesKey, value);
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }
}

