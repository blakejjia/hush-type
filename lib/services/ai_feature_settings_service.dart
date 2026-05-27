import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_model.dart';
import 'ai_provider_registry.dart';

class AiFeatureRuntimeConfig {
  final bool enabled;
  final bool ready;
  final String statusMessage;
  final String providerMode;
  final String cloudProvider;
  final String requestType;
  final String apiKey;
  final String model;
  final String endpoint;
  final String customEndpoint;
  final Map<String, String> auth;
  final String? systemPrompt;
  final String? responseTextPath;

  const AiFeatureRuntimeConfig({
    required this.enabled,
    required this.ready,
    required this.statusMessage,
    required this.providerMode,
    required this.cloudProvider,
    required this.requestType,
    required this.apiKey,
    required this.model,
    required this.endpoint,
    required this.customEndpoint,
    required this.auth,
    this.systemPrompt,
    this.responseTextPath,
  });

}

class FeatureSettingsSummary {
  final bool enabled;
  final String subtitle;
  final bool needsConfiguration;

  const FeatureSettingsSummary({
    required this.enabled,
    required this.subtitle,
    required this.needsConfiguration,
  });
}

abstract class AiFeatureSettingsService {
  final String settingsKey;
  final AiProviderFeature feature;

  const AiFeatureSettingsService({
    required this.settingsKey,
    required this.feature,
  });

  Map<String, dynamic> buildDefaultSettings();

  String get defaultModel;

  String buildNotConfiguredMessage();

  AiFeatureRuntimeConfig resolveRuntime(Map<String, dynamic> settings);

  Future<FeatureSettingsSummary> getSummary();

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(settingsKey);
    if (str != null) {
      try {
        final settings = jsonDecode(str) as Map<String, dynamic>;
        if (settings['runtime'] is! Map<String, dynamic>) {
          await saveSettings(settings);
        }
        return settings;
      } catch (_) {}
    }
    return buildDefaultSettings();
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings));
  }

  String normalizeProvider(String provider) {
    return provider.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Map<String, dynamic> getProviderSettings(
    Map<String, dynamic> settings,
    String provider,
  ) {
    final providers = settings['providers'] as Map<String, dynamic>? ?? {};
    final normProvider = normalizeProvider(provider);
    return providers[normProvider] as Map<String, dynamic>? ?? {};
  }

  void updateProviderSettings(
    Map<String, dynamic> settings,
    String provider,
    String key,
    dynamic value,
  ) {
    final providers = settings['providers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final normProvider = normalizeProvider(provider);
    final providerSettings = Map<String, dynamic>.from(
      providers[normProvider] as Map<String, dynamic>? ?? {},
    );
    providerSettings[key] = value;
    providers[normProvider] = providerSettings;
    settings['providers'] = providers;
  }

  Future<String> getProvider() async {
    final settings = await getSettings();
    return settings['provider'] as String? ?? 'cloud_providers';
  }

  Future<void> setProvider(String value) async {
    final settings = await getSettings();
    settings['provider'] = value;
    await saveSettings(settings);
  }

  Future<String> getCloudProvider() async {
    final settings = await getSettings();
    return settings['cloud_provider'] as String? ?? 'OpenAI';
  }

  Future<void> setCloudProvider(String value) async {
    final settings = await getSettings();
    settings['cloud_provider'] = value;
    await saveSettings(settings);
  }

  Future<String> getApiKey({String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = getProviderSettings(settings, resolvedProvider);
    return providerSettings['api_key'] as String? ?? '';
  }

  Future<void> setApiKey(String value, {String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    updateProviderSettings(settings, resolvedProvider, 'api_key', value);
    await saveSettings(settings);
  }

  Future<String> getEndpoint({String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = getProviderSettings(settings, resolvedProvider);
    return providerSettings['endpoint'] as String? ?? '';
  }

  Future<void> setEndpoint(String value, {String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    updateProviderSettings(settings, resolvedProvider, 'endpoint', value);
    await saveSettings(settings);
  }

  Future<String> getModel({String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = getProviderSettings(settings, resolvedProvider);
    return providerSettings['model'] as String? ?? defaultModel;
  }

  Future<void> setModel(String value, {String? provider}) async {
    final settings = await getSettings();
    final resolvedProvider = provider ?? settings['cloud_provider'] as String? ?? 'OpenAI';
    updateProviderSettings(settings, resolvedProvider, 'model', value);
    await saveSettings(settings);
  }

  Future<ModelFetchResult> fetchAvailableModels({
    String? cloudProvider,
    String? apiKey,
    String? customEndpoint,
  }) async {
    final resolvedProviderName = cloudProvider ?? await getCloudProvider();
    final resolvedApiKey = (apiKey ?? await getApiKey()).trim();
    final resolvedCustomEndpoint = (customEndpoint ?? await getEndpoint()).trim();

    if (resolvedApiKey.isEmpty) {
      return const ModelFetchResult.failure('Enter an API key.');
    }

    final provider = AiProviderRegistry.get(resolvedProviderName);

    try {
      final response = await provider.fetchModels(
        feature: feature,
        apiKey: resolvedApiKey,
        customEndpoint: resolvedCustomEndpoint,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ModelFetchResult.failure(AiProviderRegistry.extractErrorMessage(response));
      }

      final data = AiProviderRegistry.decodeJson(response.body);
      if (data == null) {
        return const ModelFetchResult.failure(
          'The provider returned invalid JSON for the models list.',
        );
      }

      final models = transformFetchedModels(provider.parseModels(feature, data));
      return ModelFetchResult.success(models);
    } on TimeoutException {
      return const ModelFetchResult.failure(
        'Timed out while fetching models from the provider.',
      );
    } catch (e) {
      debugPrint('Error fetching $feature models: $e');
      return ModelFetchResult.failure('Failed to fetch models: $e');
    }
  }

  List<ApiModel> transformFetchedModels(List<ApiModel> models) => models;
}
