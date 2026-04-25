import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _isSetupCompleteKey = 'isSetupComplete';
  static const String _selectedLanguagesKey = 'flutter.selected_languages';

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
}
