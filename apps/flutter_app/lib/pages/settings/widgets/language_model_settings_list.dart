import 'package:flutter/material.dart';
import '../../../services/llm_settings_service.dart';
import '../../../services/model_provider_utils.dart';
import '../../../models/api_model.dart';
import 'shared/settings_common_widgets.dart';

class LanguageModelSettingsList extends StatefulWidget {
  final String title;
  const LanguageModelSettingsList({super.key, required this.title});

  @override
  State<LanguageModelSettingsList> createState() => _LanguageModelSettingsListState();
}

class _LanguageModelSettingsListState extends State<LanguageModelSettingsList> {
  final LLMSettingsService _settingsService = LLMSettingsService();
  String _selectedProvider = 'cloud_providers';
  String _selectedCloudProvider = 'OpenAI';
  String _selectedModel = '';
  bool _enableCleanup = true;
  bool _modelsLoaded = false;
  bool _isLoadingModels = false;
  bool _isApiKeyVerified = false;
  String? _errorText;
  List<ApiModel> _availableModels = [];
  
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadProviderSettings(String provider) async {
    final apiKey = await _settingsService.getApiKey(provider: provider);
    final endpoint = await _settingsService.getEndpoint(provider: provider);
    final model = await _settingsService.getModel(provider: provider);

    if (!mounted) return;

    setState(() {
      _selectedCloudProvider = provider;
      _apiKeyController.text = apiKey;
      _endpointController.text = endpoint;
      _selectedModel = model;
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

  Future<void> _loadSettings() async {
    final enabled = await _settingsService.isEnabled();
    final provider = await _settingsService.getProvider();
    final cloudProvider = await _settingsService.getCloudProvider();
    final apiKey = await _settingsService.getApiKey(provider: cloudProvider);
    final endpoint = await _settingsService.getEndpoint(provider: cloudProvider);
    final model = await _settingsService.getModel(provider: cloudProvider);
    final prompt = await _settingsService.getSystemPrompt();

    if (mounted) {
      setState(() {
        _enableCleanup = enabled;
        _selectedProvider = provider;
        _selectedCloudProvider = cloudProvider;
        _apiKeyController.text = apiKey;
        _endpointController.text = endpoint;
        _promptController.text = prompt;
        _selectedModel = model;
        
      });
    }

    if (ModelProviderUtils.isValidApiKey(cloudProvider, apiKey)) {
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
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _promptController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: Text('Enable ${widget.title.toLowerCase()}'),
            subtitle: const Text('Use AI to format text and follow voice commands'),
            value: _enableCleanup,
            onChanged: (val) {
              setState(() => _enableCleanup = val);
              _settingsService.setEnabled(val);
            },
          ),
        ),
        if (_enableCleanup) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  _promptController.text = LLMSettingsService.defaultSystemPrompt;
                  _settingsService.setSystemPrompt(LLMSettingsService.defaultSystemPrompt);
                },
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _promptController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter system prompt',
                ),
                onChanged: (val) {
                  _settingsService.setSystemPrompt(val);
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        RadioGroup<String>(
          groupValue: _selectedProvider,
          onChanged: (id) {
            if (!_enableCleanup || id == null) return;
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
                enabled: _enableCleanup,
              ),
              MainProviderTile(
                id: 'cloud_providers',
                title: 'Bring Your Own Key',
                subtitle: 'Use your own API key with supported providers.',
                icon: Icons.key_outlined,
                isSelected: _selectedProvider == 'cloud_providers',
                isActive: _selectedProvider == 'cloud_providers',
                enabled: _enableCleanup,
              ),
            ],
          ),
        ),
        
        if (_selectedProvider == 'cloud_providers') 
          ProviderConfigView(
            selectedCloudProvider: _selectedCloudProvider,
            providers: const ['OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Custom'],
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
            defaultEndpoint: ModelProviderUtils.getEndpointForProvider(_selectedCloudProvider),
            enabled: _enableCleanup,
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
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedModel = '');
                            _settingsService.setModel('', provider: _selectedCloudProvider);
                          }, 
                          child: const Text('Reset')
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoadingModels ? null : _fetchModels, 
                          child: const Text('Refresh')
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_availableModels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No models found from this endpoint.', style: TextStyle(color: Colors.red))),
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
                      children: _availableModels.map((m) => _buildModelItem(m.id, m.ownedBy)).toList(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelItem(String name, String owner) {
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
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text('Owner: $owner', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
