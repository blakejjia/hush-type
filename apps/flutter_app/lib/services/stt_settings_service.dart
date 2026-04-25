import '../models/api_model.dart';
import 'ai_feature_settings_service.dart';
import 'ai_provider_registry.dart';

class STTSettingsService extends AiFeatureSettingsService {
  STTSettingsService()
      : super(
          settingsKey: 'stt_settings',
          feature: AiProviderFeature.stt,
        );

  @override
  Map<String, dynamic> buildDefaultSettings() {
    return {
      'provider': 'cloud_providers',
      'cloud_provider': 'OpenAI',
      'providers': <String, dynamic>{},
    };
  }

  @override
  String get defaultModel => 'whisper-1';

  @override
  String buildNotConfiguredMessage() => 'Please configure first before using.';

  @override
  List<ApiModel> transformFetchedModels(List<ApiModel> models) {
    return models.where(_isSpeechToTextModel).toList(growable: false);
  }

  @override
  AiFeatureRuntimeConfig resolveRuntime(Map<String, dynamic> settings) {
    final providerMode = settings['provider'] as String? ?? 'cloud_providers';
    final cloudProvider = settings['cloud_provider'] as String? ?? 'OpenAI';
    final providerSettings = getProviderSettings(settings, cloudProvider);
    final apiKey = (providerSettings['api_key'] as String? ?? '').trim();
    final customEndpoint = (providerSettings['endpoint'] as String? ?? '').trim();
    final model = (providerSettings['model'] as String? ?? defaultModel).trim();
    final provider = AiProviderRegistry.get(cloudProvider);
    final requestType = provider.requestType(feature);
    final endpoint = provider.resolveRuntimeEndpoint(
      feature: feature,
      model: model,
      customEndpoint: customEndpoint,
    );

    var statusMessage = 'Ready';
    var ready = true;

    if (providerMode != 'cloud_providers') {
      ready = false;
      statusMessage = buildNotConfiguredMessage();
    } else if (apiKey.isEmpty) {
      ready = false;
      statusMessage = buildNotConfiguredMessage();
    } else {
      final keyError = provider.validateApiKey(apiKey);
      if (keyError != null) {
        ready = false;
        statusMessage = keyError;
      } else if (model.isEmpty) {
        ready = false;
        statusMessage = 'Please select a speech-to-text model.';
      } else if (endpoint.isEmpty || requestType.isEmpty) {
        ready = false;
        statusMessage = buildNotConfiguredMessage();
      }
    }

    return AiFeatureRuntimeConfig(
      enabled: true,
      ready: ready,
      statusMessage: statusMessage,
      providerMode: providerMode,
      cloudProvider: cloudProvider,
      requestType: requestType,
      apiKey: apiKey,
      model: model,
      endpoint: endpoint,
      customEndpoint: customEndpoint,
      responseTextPath: 'text',
      auth: provider.authConfig.toJson(),
    );
  }

  @override
  Future<FeatureSettingsSummary> getSummary() async {
    final settings = await getSettings();
    final runtime = resolveRuntime(settings);

    if (runtime.providerMode != 'cloud_providers') {
      return const FeatureSettingsSummary(
        enabled: true,
        subtitle: 'Cloud',
        needsConfiguration: false,
      );
    }

    if (!runtime.ready) {
      return const FeatureSettingsSummary(
        enabled: true,
        subtitle: 'need configuration',
        needsConfiguration: true,
      );
    }

    return FeatureSettingsSummary(
      enabled: true,
      subtitle: '${runtime.cloudProvider}: ${runtime.model}',
      needsConfiguration: false,
    );
  }

  bool _isSpeechToTextModel(ApiModel model) {
    final id = model.id.toLowerCase();
    return id.contains('whisper') ||
        id.contains('transcribe') ||
        id.contains('distil-whisper') ||
        id.contains('speech-to-text');
  }
}
