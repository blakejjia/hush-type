import 'package:shared_preferences/shared_preferences.dart';

class LLMSettingsService {
  static const String _enabledKey = 'flutter.llm_enabled';
  static const String _providerKey = 'flutter.llm_provider';
  static const String _cloudProviderKey = 'flutter.llm_cloud_provider';
  static const String _apiKeyKey = 'flutter.llm_api_key';
  static const String _endpointKey = 'flutter.llm_endpoint';
  static const String _modelKey = 'flutter.llm_model';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<String> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey) ?? 'cloud_providers';
  }

  Future<void> setProvider(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, value);
  }

  Future<String> getCloudProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cloudProviderKey) ?? 'OpenAI';
  }

  Future<void> setCloudProvider(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudProviderKey, value);
  }

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  Future<void> setApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, value);
  }

  Future<String> getEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_endpointKey) ?? '';
  }

  Future<void> setEndpoint(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endpointKey, value);
  }

  Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? '';
  }

  Future<void> setModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, value);
  }
}
