import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/api_model.dart';
import 'model_provider_utils.dart';

class STTSettingsService {
  static const String _settingsKey = 'flutter.stt_settings';

  Future<Map<String, dynamic>> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_settingsKey);
    if (str != null) {
      try {
        final settings = jsonDecode(str) as Map<String, dynamic>;
        if (settings['runtime'] is! Map<String, dynamic>) {
          await _saveSettings(settings);
        }
        return settings;
      } catch (_) {}
    }
    return {
      'provider': 'cloud_providers',
      'cloud_provider': 'OpenAI',
      'providers': <String, dynamic>{},
    };
  }

  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    settings['runtime'] = _buildRuntimeConfig(settings);
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

  Future<String> getModel({String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = _getProviderSettings(settings, resolvedProvider);
    return providerSettings['model'] as String? ?? 'whisper-1';
  }

  Future<void> setModel(String value, {String? provider}) async {
    final settings = await _getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    _updateProviderSettings(settings, resolvedProvider, 'model', value);
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
      String baseUrl = ModelProviderUtils.getEndpointForProvider(
        resolvedProvider,
        isSTT: true,
      );
      if (resolvedProvider == 'Custom' && resolvedCustomEndpoint.isNotEmpty) {
        baseUrl = resolvedCustomEndpoint;
      }

      if (baseUrl.isEmpty) {
        return ModelFetchResult.failure('No endpoint configured for $resolvedProvider.');
      }

      final response = await http.get(
        Uri.parse(ModelProviderUtils.buildModelsEndpoint(baseUrl)),
        headers: {
          'Authorization': 'Bearer $resolvedApiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ModelFetchResult.failure(_extractErrorMessage(response));
      }

      final data = _decodeJson(response.body);
      if (data == null) {
        return const ModelFetchResult.failure('The provider returned invalid JSON for the models list.');
      }

      final modelsJson = data['data'];
      if (modelsJson is! List) {
        return const ModelFetchResult.success([]);
      }

      final allModels = modelsJson
          .whereType<Map<String, dynamic>>()
          .map(ApiModel.fromJson)
          .toList();
      final sttModels = allModels.where(_isSpeechToTextModel).toList();

      return ModelFetchResult.success(sttModels);
    } on TimeoutException {
      return const ModelFetchResult.failure('Timed out while fetching models from the provider.');
    } catch (e) {
      debugPrint('Error fetching STT models: $e');
      return ModelFetchResult.failure('Failed to fetch models: $e');
    }
  }

  bool _isSpeechToTextModel(ApiModel model) {
    final id = model.id.toLowerCase();
    return id.contains('whisper') ||
        id.contains('transcribe') ||
        id.contains('distil-whisper') ||
        id.contains('speech-to-text');
  }

  Map<String, dynamic>? _decodeJson(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
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

  Map<String, dynamic> _buildRuntimeConfig(Map<String, dynamic> settings) {
    final providerMode = settings['provider'] as String? ?? 'cloud_providers';
    final cloudProvider = settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = _getProviderSettings(settings, cloudProvider);
    final apiKey = (providerSettings['api_key'] as String? ?? '').trim();
    final customEndpoint = (providerSettings['endpoint'] as String? ?? '').trim();
    final model = (providerSettings['model'] as String? ?? 'whisper-1').trim();

    final requestType = ModelProviderUtils.getSttRequestType(cloudProvider);
    final endpoint = cloudProvider == 'Custom'
        ? ModelProviderUtils.buildTranscriptionsEndpoint(customEndpoint)
        : ModelProviderUtils.getEndpointForProvider(cloudProvider, isSTT: true);
    final auth = ModelProviderUtils.getAuthConfig(cloudProvider);

    String statusMessage = 'Ready';
    bool ready = true;

    if (providerMode != 'cloud_providers') {
      ready = false;
      statusMessage = 'Please configurate first before using.';
    } else if (apiKey.isEmpty) {
      ready = false;
      statusMessage = 'Please configurate first before using.';
    } else {
      final keyError = ModelProviderUtils.getApiKeyValidationError(cloudProvider, apiKey);
      if (keyError != null) {
        ready = false;
        statusMessage = keyError;
      } else if (model.isEmpty) {
        ready = false;
        statusMessage = 'Please select a speech-to-text model.';
      } else if (endpoint.isEmpty || requestType.isEmpty) {
        ready = false;
        statusMessage = 'Please configurate first before using.';
      }
    }

    return {
      'ready': ready,
      'status_message': statusMessage,
      'provider_mode': providerMode,
      'cloud_provider': cloudProvider,
      'request_type': requestType,
      'response_text_path': 'text',
      'api_key': apiKey,
      'model': model,
      'endpoint': endpoint,
      'custom_endpoint': customEndpoint,
      'auth': auth,
    };
  }
}
