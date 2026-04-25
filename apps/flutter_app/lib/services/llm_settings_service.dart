import 'dart:async';
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
  static const String _settingsKey = 'flutter.llm_settings';

  Future<Map<String, dynamic>> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_settingsKey);
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {
      'enabled': true,
      'provider': 'cloud_providers',
      'cloud_provider': 'OpenAI',
      'providers': <String, dynamic>{},
    };
  }

  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  String _normalizeProvider(String provider) {
    return provider.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Map<String, dynamic> _getProviderSettings(Map<String, dynamic> settings, String provider) {
    final providers = settings['providers'] as Map<String, dynamic>? ?? {};
    final normProvider = _normalizeProvider(provider);
    return providers[normProvider] as Map<String, dynamic>? ?? {};
  }

  void _updateProviderSettings(Map<String, dynamic> settings, String provider, String key, dynamic value) {
    final providers = settings['providers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final normProvider = _normalizeProvider(provider);
    final providerSettings = Map<String, dynamic>.from(providers[normProvider] as Map<String, dynamic>? ?? {});
    providerSettings[key] = value;
    providers[normProvider] = providerSettings;
    settings['providers'] = providers;
  }

  Future<bool> isEnabled() async {
    final settings = await _getSettings();
    return settings['enabled'] as bool? ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final settings = await _getSettings();
    settings['enabled'] = value;
    await _saveSettings(settings);
  }

  Future<String> getProvider() async {
    final settings = await _getSettings();
    return settings['provider'] as String? ?? 'cloud_providers';
  }

  Future<void> setProvider(String value) async {
    final settings = await _getSettings();
    settings['provider'] = value;
    await _saveSettings(settings);
  }

  Future<String> getCloudProvider() async {
    final settings = await _getSettings();
    return settings['cloud_provider'] as String? ?? 'OpenAI';
  }

  Future<void> setCloudProvider(String value) async {
    final settings = await _getSettings();
    settings['cloud_provider'] = value;
    await _saveSettings(settings);
  }

  Future<String> getApiKey({String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = _getProviderSettings(settings, resolvedProvider);
    return providerSettings['api_key'] as String? ?? '';
  }

  Future<void> setApiKey(String value, {String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    _updateProviderSettings(settings, resolvedProvider, 'api_key', value);
    await _saveSettings(settings);
  }

  Future<String> getEndpoint({String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = _getProviderSettings(settings, resolvedProvider);
    return providerSettings['endpoint'] as String? ?? '';
  }

  Future<void> setEndpoint(String value, {String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    _updateProviderSettings(settings, resolvedProvider, 'endpoint', value);
    await _saveSettings(settings);
  }

  Future<String> getModel({String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = _getProviderSettings(settings, resolvedProvider);
    return providerSettings['model'] as String? ?? '';
  }

  Future<void> setModel(String value, {String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    _updateProviderSettings(settings, resolvedProvider, 'model', value);
    await _saveSettings(settings);
  }

  Future<ModelFetchResult> fetchAvailableModels({
    String? cloudProvider,
    String? apiKey,
    String? customEndpoint,
  }) async {
    final resolvedProvider = cloudProvider ?? await getCloudProvider();
    final resolvedApiKey = (apiKey ?? await getApiKey()).trim();
    final resolvedCustomEndpoint = (customEndpoint ?? await getEndpoint()).trim();

    if (resolvedApiKey.isEmpty) {
      return const ModelFetchResult.failure('Enter an API key.');
    }

    try {
      final response = await _fetchModelsResponse(
        cloudProvider: resolvedProvider,
        apiKey: resolvedApiKey,
        customEndpoint: resolvedCustomEndpoint,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ModelFetchResult.failure(_extractErrorMessage(response));
      }

      final data = _decodeJson(response.body);
      if (data == null) {
        return const ModelFetchResult.failure('The provider returned invalid JSON for the models list.');
      }

      final models = _parseModels(resolvedProvider, data);
      return ModelFetchResult.success(models);
    } on TimeoutException {
      return const ModelFetchResult.failure('Timed out while fetching models from the provider.');
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return ModelFetchResult.failure('Failed to fetch models: $e');
    }
  }

  Future<http.Response> _fetchModelsResponse({
    required String cloudProvider,
    required String apiKey,
    required String customEndpoint,
  }) {
    switch (cloudProvider) {
      case 'Anthropic':
        final url = Uri.parse(ModelProviderUtils.buildModelsEndpoint(
          ModelProviderUtils.getEndpointForProvider(cloudProvider),
        ));
        return http.get(
          url,
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': ModelProviderUtils.anthropicVersion,
            'content-type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      case 'Google Gemini':
        final endpoint = ModelProviderUtils.getEndpointForProvider(cloudProvider);
        final uri = Uri.parse(endpoint).replace(
          pathSegments: [...Uri.parse(endpoint).pathSegments, 'models'],
          queryParameters: {
            'key': apiKey,
          },
        );
        return http.get(
          uri,
          headers: const {
            'content-type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      default:
        String baseUrl = ModelProviderUtils.getEndpointForProvider(cloudProvider);
        if (cloudProvider == 'Custom' && customEndpoint.isNotEmpty) {
          baseUrl = customEndpoint;
        }
        if (baseUrl.isEmpty) {
          throw StateError('No endpoint configured for $cloudProvider.');
        }
        final url = Uri.parse(ModelProviderUtils.buildModelsEndpoint(baseUrl));
        return http.get(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
    }
  }

  Map<String, dynamic>? _decodeJson(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  List<ApiModel> _parseModels(String cloudProvider, Map<String, dynamic> data) {
    switch (cloudProvider) {
      case 'Google Gemini':
        final modelsJson = data['models'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map((model) {
              final name = (model['name'] ?? '') as String;
              final id = name.startsWith('models/') ? name.substring('models/'.length) : name;
              final owner = (model['displayName'] ?? 'Google Gemini') as String;
              return ApiModel(id: id, ownedBy: owner);
            })
            .where((model) => model.id.isNotEmpty)
            .toList();
      case 'Anthropic':
        final modelsJson = data['data'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map((model) => ApiModel(
                  id: (model['id'] ?? '') as String,
                  ownedBy: (model['display_name'] ?? 'Anthropic') as String,
                ))
            .where((model) => model.id.isNotEmpty)
            .toList();
      default:
        final modelsJson = data['data'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map(ApiModel.fromJson)
            .toList();
    }
  }

  String _extractErrorMessage(http.Response response) {
    final data = _decodeJson(response.body);
    if (data != null) {
      final nestedError = data['error'];
      if (nestedError is Map<String, dynamic>) {
        final message = nestedError['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return 'Model lookup failed with status ${response.statusCode}.';
  }
}
