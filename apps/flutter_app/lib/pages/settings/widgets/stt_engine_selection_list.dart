import 'package:flutter/material.dart';
import '../../../services/stt_settings_service.dart';
import '../../../services/model_provider_utils.dart';
import '../../../models/api_model.dart';
import 'shared/settings_common_widgets.dart';

class STTEngineSelectionList extends StatefulWidget {
  const STTEngineSelectionList({super.key});

  @override
  State<STTEngineSelectionList> createState() => _STTEngineSelectionListState();
}

class _STTEngineSelectionListState extends State<STTEngineSelectionList> {
  final STTSettingsService _settingsService = STTSettingsService();
  String _selectedProvider = 'cloud_providers';
  String _selectedCloudProvider = 'OpenAI';
  String _selectedModel = 'whisper-1';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();
  
  bool _modelsLoaded = false;
  bool _isLoadingModels = false;
  bool _isApiKeyVerified = false;
  String? _errorText;
  List<ApiModel> _availableModels = [];

  Future<void> _loadProviderSettings(String provider) async {
    final apiKey = await _settingsService.getApiKey(provider: provider);
    final endpoint = await _settingsService.getEndpoint(provider: provider);
    final model = await _settingsService.getModel(provider: provider);

    if (!mounted) return;

    setState(() {
      _selectedCloudProvider = provider;
      _selectedModel = model;
      _apiKeyController.text = apiKey;
      _endpointController.text = endpoint;
      _availableModels = [];
      _modelsLoaded = false;
      _isLoadingModels = false;
      _isApiKeyVerified = false;
      _errorText = ModelProviderUtils.getApiKeyValidationError(provider, apiKey);
    });

    if (ModelProviderUtils.isValidApiKey(provider, apiKey)) {
      _fetchModels();
    }
  }

  void _fetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    final endpoint = _endpointController.text.trim();
    final validationError = ModelProviderUtils.getApiKeyValidationError(
      _selectedCloudProvider,
      apiKey,
    );

    if (validationError != null) {
      setState(() {
        _availableModels = [];
        _errorText = validationError;
        _modelsLoaded = false;
        _isLoadingModels = false;
        _isApiKeyVerified = false;
      });
      return;
    }

    await _settingsService.setCloudProvider(_selectedCloudProvider);
    await _settingsService.setApiKey(apiKey, provider: _selectedCloudProvider);
    await _settingsService.setEndpoint(endpoint, provider: _selectedCloudProvider);
    setState(() {
      _isLoadingModels = true;
      _modelsLoaded = false;
      _isApiKeyVerified = false;
      _errorText = null;
    });
    
    final result = await _settingsService.fetchAvailableModels(
      cloudProvider: _selectedCloudProvider,
      apiKey: apiKey,
      customEndpoint: endpoint,
    );
    
    if (mounted) {
      setState(() {
        _isLoadingModels = false;
        _availableModels = result.models;
        _modelsLoaded = result.isSuccess;
        _isApiKeyVerified = result.isSuccess;
        _errorText = result.errorMessage;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settingsService.getProvider();
    final cloudProvider = await _settingsService.getCloudProvider();
    final model = await _settingsService.getModel(provider: cloudProvider);
    final apiKey = await _settingsService.getApiKey(provider: cloudProvider);
    final endpoint = await _settingsService.getEndpoint(provider: cloudProvider);

    if (mounted) {
      setState(() {
        _selectedProvider = provider;
        _selectedCloudProvider = cloudProvider;
        _selectedModel = model;
        _apiKeyController.text = apiKey;
        _endpointController.text = endpoint;
        
      });
    }

    if (ModelProviderUtils.isValidApiKey(cloudProvider, apiKey)) {
      _fetchModels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RadioGroup<String>(
          groupValue: _selectedProvider,
          onChanged: (id) {
            if (id == null) return;
            setState(() => _selectedProvider = id);
            _settingsService.setProvider(id);
          },
          child: Column(
            children: [
              MainProviderTile(
                id: 'cloud',
                title: 'Cloud',
                subtitle: 'Reliable accuracy. No setup needed.',
                icon: Icons.cloud_outlined,
                isSelected: _selectedProvider == 'cloud',
                isActive: _selectedProvider == 'cloud',
              ),
              MainProviderTile(
                id: 'cloud_providers',
                title: 'Bring Your Own Key',
                subtitle: 'Use your own API key with supported providers.',
                icon: Icons.key_outlined,
                isSelected: _selectedProvider == 'cloud_providers',
                isActive: _selectedProvider == 'cloud_providers',
              ),
            ],
          ),
        ),
        if (_selectedProvider == 'cloud_providers') 
          ProviderConfigView(
            selectedCloudProvider: _selectedCloudProvider,
            providers: const ['OpenAI', 'Groq', 'Mistral', 'Custom'],
            apiKeyController: _apiKeyController,
            endpointController: _endpointController,
            apiKeyFocusNode: _apiKeyFocusNode,
            isLoadingModels: _isLoadingModels,
            isApiKeyVerified: _isApiKeyVerified,
            isBasicValid: ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text),
            modelsLoaded: _modelsLoaded,
            errorText: _errorText,
            helpUrl: ModelProviderUtils.getApiKeyHelpUrl(_selectedCloudProvider),
            apiKeyPlaceholder: ModelProviderUtils.getApiKeyPlaceholder(_selectedCloudProvider),
            defaultEndpoint: ModelProviderUtils.getEndpointForProvider(_selectedCloudProvider, isSTT: true),
            onProviderSelected: (p) async {
              await _settingsService.setCloudProvider(p);
              await _loadProviderSettings(p);
            },
            onApiKeyChanged: (val) async {
              await _settingsService.setApiKey(val, provider: _selectedCloudProvider);
              setState(() {
                _availableModels = [];
                _isApiKeyVerified = false;
                _modelsLoaded = false;
                _errorText = ModelProviderUtils.getApiKeyValidationError(_selectedCloudProvider, val);
              });
              if (ModelProviderUtils.isValidApiKey(_selectedCloudProvider, val)) {
                _fetchModels();
              }
            },
            onEndpointChanged: (val) async {
              await _settingsService.setEndpoint(val, provider: _selectedCloudProvider);
              setState(() {
                _availableModels = [];
                _modelsLoaded = false;
                _isApiKeyVerified = false;
                _errorText = null;
              });
              if (_selectedCloudProvider == 'Custom' &&
                  ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text) &&
                  val.trim().isNotEmpty) {
                _fetchModels();
              }
            },
            onClearApiKey: () async {
              _apiKeyController.clear();
              await _settingsService.setApiKey('', provider: _selectedCloudProvider);
              if (!mounted) return;
              setState(() {
                _availableModels = [];
                _modelsLoaded = false;
                _isLoadingModels = false;
                _isApiKeyVerified = false;
                _errorText = null;
              });
            },
            modelsList: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Models', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ElevatedButton(
                      onPressed: _isLoadingModels ? null : _fetchModels, 
                      child: const Text('Refresh')
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_availableModels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No speech-to-text models found from this endpoint.', style: TextStyle(color: Colors.red))),
                  )
                else
                  RadioGroup<String>(
                    groupValue: _selectedModel,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedModel = v);
                      _settingsService.setModel(v, provider: _selectedCloudProvider);
                    },
                    child: Column(
                      children: _availableModels.map((m) => _buildModelTile(m.id, 'Owner: ${m.ownedBy}', _selectedModel == m.id)).toList(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelTile(String name, String desc, bool active) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedModel == name;

    return Card(
      key: ValueKey(name),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedModel = name);
          _settingsService.setModel(name, provider: _selectedCloudProvider);
        },
        dense: true,
        leading: Radio<String>(
          value: name,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: active ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
          child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ) : null,
      ),
    );
  }
}
