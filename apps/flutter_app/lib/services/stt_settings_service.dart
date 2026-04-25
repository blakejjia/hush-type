import 'dart:async';
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

  String _scopedKey(String baseKey, String provider) {
    final normalizedProvider = provider.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${baseKey}_$normalizedProvider';
  }

  Future<String> _resolveProvider(String? provider) async {
    return provider ?? await getCloudProvider();
  }

  Future<String> getModel({String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    return prefs.getString(_scopedKey(_modelKey, resolvedProvider)) ??
        prefs.getString(_modelKey) ??
        'whisper-1';
  }

  Future<void> setModel(String value, {String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    await prefs.setString(_scopedKey(_modelKey, resolvedProvider), value);
  }

  Future<String> getApiKey({String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    return prefs.getString(_scopedKey(_apiKeyKey, resolvedProvider)) ??
        prefs.getString(_apiKeyKey) ??
        '';
  }

  Future<void> setApiKey(String value, {String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    await prefs.setString(_scopedKey(_apiKeyKey, resolvedProvider), value);
  }

  Future<String> getEndpoint({String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    return prefs.getString(_scopedKey(_endpointKey, resolvedProvider)) ??
        prefs.getString(_endpointKey) ??
        '';
  }

  Future<void> setEndpoint(String value, {String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedProvider = await _resolveProvider(provider);
    await prefs.setString(_scopedKey(_endpointKey, resolvedProvider), value);
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
}
