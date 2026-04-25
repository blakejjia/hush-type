import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _isSetupCompleteKey = 'isSetupComplete';
  static const String _selectedLanguagesKey = 'flutter.selected_languages';

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
}
