import 'package:flutter/material.dart';

import '../../../../models/api_model.dart';
import '../../../../services/ai_feature_settings_service.dart';
import '../../../../services/ai_provider_registry.dart';

class ProviderSettingsController extends ChangeNotifier {
  ProviderSettingsController({required this.settingsService});

  final AiFeatureSettingsService settingsService;

  String selectedProvider = 'cloud_providers';
  String selectedCloudProvider = 'OpenAI';
  String selectedModel = '';
  bool modelsLoaded = false;
  bool isLoadingModels = false;
  bool isApiKeyVerified = false;
  String? errorText;
  List<ApiModel> availableModels = const [];

  final TextEditingController apiKeyController = TextEditingController();
  final TextEditingController endpointController = TextEditingController();
  final FocusNode apiKeyFocusNode = FocusNode();

  ProviderSpec get _providerSpec => AiProviderRegistry.get(selectedCloudProvider);

  bool get isBasicValid => _providerSpec.validateApiKey(apiKeyController.text) == null;

  String get helpUrl => _providerSpec.helpUrl;

  String get apiKeyPlaceholder => _providerSpec.apiKeyPlaceholder;

  String get defaultEndpoint => _providerSpec.defaultBaseUrl(settingsService.feature);

  Future<void> load() async {
    selectedProvider = await settingsService.getProvider();
    selectedCloudProvider = await settingsService.getCloudProvider();
    selectedModel = await settingsService.getModel(provider: selectedCloudProvider);
    apiKeyController.text =
        await settingsService.getApiKey(provider: selectedCloudProvider);
    endpointController.text =
        await settingsService.getEndpoint(provider: selectedCloudProvider);
    notifyListeners();

    if (isBasicValid) {
      await fetchModels();
    }
  }

  Future<void> loadProviderSettings(String provider) async {
    selectedCloudProvider = provider;
    selectedModel = await settingsService.getModel(provider: provider);
    apiKeyController.text = await settingsService.getApiKey(provider: provider);
    endpointController.text = await settingsService.getEndpoint(provider: provider);
    availableModels = const [];
    modelsLoaded = false;
    isLoadingModels = false;
    isApiKeyVerified = false;
    errorText = AiProviderRegistry.get(provider).validateApiKey(apiKeyController.text);
    notifyListeners();

    if (AiProviderRegistry.get(provider).validateApiKey(apiKeyController.text) == null) {
      await fetchModels();
    }
  }

  Future<void> setProviderMode(String value) async {
    selectedProvider = value;
    notifyListeners();
    await settingsService.setProvider(value);
  }

  Future<void> selectCloudProvider(String provider) async {
    await settingsService.setCloudProvider(provider);
    await loadProviderSettings(provider);
  }

  Future<void> updateApiKey(String value) async {
    await settingsService.setApiKey(value, provider: selectedCloudProvider);
    availableModels = const [];
    isApiKeyVerified = false;
    modelsLoaded = false;
    errorText = _providerSpec.validateApiKey(value);
    notifyListeners();

    if (_providerSpec.validateApiKey(value) == null) {
      await fetchModels();
    }
  }

  Future<void> updateEndpoint(String value) async {
    await settingsService.setEndpoint(value, provider: selectedCloudProvider);
    availableModels = const [];
    modelsLoaded = false;
    isApiKeyVerified = false;
    errorText = null;
    notifyListeners();

    if (selectedCloudProvider == 'Custom' &&
        isBasicValid &&
        value.trim().isNotEmpty) {
      await fetchModels();
    }
  }

  Future<void> clearApiKey() async {
    apiKeyController.clear();
    await settingsService.setApiKey('', provider: selectedCloudProvider);
    availableModels = const [];
    modelsLoaded = false;
    isLoadingModels = false;
    isApiKeyVerified = false;
    errorText = null;
    notifyListeners();
  }

  Future<void> selectModel(String value) async {
    selectedModel = value;
    notifyListeners();
    await settingsService.setModel(value, provider: selectedCloudProvider);
  }

  Future<void> resetModel() async {
    selectedModel = '';
    notifyListeners();
    await settingsService.setModel('', provider: selectedCloudProvider);
  }

  Future<void> fetchModels() async {
    final apiKey = apiKeyController.text.trim();
    final endpoint = endpointController.text.trim();
    final validationError = _providerSpec.validateApiKey(apiKey);

    if (validationError != null) {
      availableModels = const [];
      errorText = validationError;
      modelsLoaded = false;
      isLoadingModels = false;
      isApiKeyVerified = false;
      notifyListeners();
      return;
    }

    await settingsService.setCloudProvider(selectedCloudProvider);
    await settingsService.setApiKey(apiKey, provider: selectedCloudProvider);
    await settingsService.setEndpoint(endpoint, provider: selectedCloudProvider);

    isLoadingModels = true;
    modelsLoaded = false;
    isApiKeyVerified = false;
    errorText = null;
    notifyListeners();

    final result = await settingsService.fetchAvailableModels(
      cloudProvider: selectedCloudProvider,
      apiKey: apiKey,
      customEndpoint: endpoint,
    );

    isLoadingModels = false;
    availableModels = result.models;
    modelsLoaded = result.isSuccess;
    isApiKeyVerified = result.isSuccess;
    errorText = result.errorMessage;
    notifyListeners();
  }

  @override
  void dispose() {
    apiKeyController.dispose();
    endpointController.dispose();
    apiKeyFocusNode.dispose();
    super.dispose();
  }
}
