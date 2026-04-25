import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/api_model.dart';
import 'model_provider_utils.dart';

class STTSettingsService {
  static const String _providerKey = 'flutter.stt_provider';
  static const String _cloudProviderKey = 'flutter.stt_cloud_provider';
  static const String _modelKey = 'flutter.stt_model';
  static const String _apiKeyKey = 'flutter.stt_api_key';
  static const String _endpointKey = 'flutter.stt_endpoint';

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

  Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? 'whisper-1';
  }

  Future<void> setModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, value);
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

  Future<List<ApiModel>> fetchAvailableModels() async {
    final cloudProvider = await getCloudProvider();
    final apiKey = await getApiKey();
    final customEndpoint = await getEndpoint();

    String baseUrl = ModelProviderUtils.getEndpointForProvider(cloudProvider, isSTT: true);
    if (cloudProvider == 'Custom' && customEndpoint.isNotEmpty) {
      baseUrl = customEndpoint;
    }

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return [];
    }

    try {
      String rootBaseUrl = baseUrl;
      if (baseUrl.contains('/audio/transcriptions')) {
        rootBaseUrl = baseUrl.replaceAll('/audio/transcriptions', '');
      } else if (baseUrl.contains('/transcriptions')) {
        rootBaseUrl = baseUrl.replaceAll('/transcriptions', '');
      }

      String modelsEndpoint = rootBaseUrl.endsWith('/') ? '${rootBaseUrl}models' : '$rootBaseUrl/models';
      
      final url = Uri.parse(modelsEndpoint);
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] is List) {
          final List<dynamic> modelsJson = data['data'];
          final allModels = modelsJson.map((m) => ApiModel.fromJson(m)).toList();
          return allModels.where((m) => m.id.toLowerCase().contains('whisper')).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching STT models: $e');
      return [];
    }
  }
}
