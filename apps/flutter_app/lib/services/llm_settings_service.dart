import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'model_provider_utils.dart';
import '../models/api_model.dart';

class LLMModel {
  final String id;
  final String ownedBy;

  LLMModel({required this.id, required this.ownedBy});

  factory LLMModel.fromJson(Map<String, dynamic> json) {
    return LLMModel(
      id: json['id'] as String,
      ownedBy: (json['owned_by'] ?? json['owner'] ?? 'unknown') as String,
    );
  }
}

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

  Future<List<ApiModel>> fetchAvailableModels() async {
    final cloudProvider = await getCloudProvider();
    final apiKey = await getApiKey();
    final customEndpoint = await getEndpoint();

    String baseUrl = ModelProviderUtils.getEndpointForProvider(cloudProvider);
    if (cloudProvider == 'Custom' && customEndpoint.isNotEmpty) {
      baseUrl = customEndpoint;
    }

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      return [];
    }

    try {
      // For OpenAI-compatible models API, it's usually /models
      // We need to be careful with the trailing slash and versioning
      String modelsEndpoint = baseUrl.endsWith('/') ? '${baseUrl}models' : '$baseUrl/models';
      
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
          return modelsJson.map((m) => ApiModel.fromJson(m)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return [];
    }
  }
}
