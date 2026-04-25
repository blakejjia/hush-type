import 'package:flutter/material.dart';
import '../../../services/llm_settings_service.dart';
import '../../../services/model_provider_utils.dart';
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
  
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settingsService.isEnabled();
    final provider = await _settingsService.getProvider();
    final cloudProvider = await _settingsService.getCloudProvider();
    final apiKey = await _settingsService.getApiKey();
    final endpoint = await _settingsService.getEndpoint();
    final model = await _settingsService.getModel();

    if (mounted) {
      setState(() {
        _enableCleanup = enabled;
        _selectedProvider = provider;
        _selectedCloudProvider = cloudProvider;
        _apiKeyController.text = apiKey;
        _endpointController.text = endpoint;
        _selectedModel = model;
        
        if (ModelProviderUtils.isValidApiKey(cloudProvider, apiKey)) {
          _fetchModels();
        }
      });
    }
  }

  void _fetchModels() async {
    if (!ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text)) return;

    _settingsService.setApiKey(_apiKeyController.text);
    setState(() {
      _isLoadingModels = true;
      _modelsLoaded = false;
      _isApiKeyVerified = false;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isLoadingModels = false;
        _modelsLoaded = true;
        _isApiKeyVerified = true;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
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
        const SizedBox(height: 24),
        MainProviderTile(
          id: 'cloud',
          title: 'Cloud',
          subtitle: 'Reliable accuracy. No setup needed.',
          icon: Icons.cloud_outlined,
          isSelected: _selectedProvider == 'cloud',
          isActive: _selectedProvider == 'cloud',
          groupValue: _selectedProvider,
          enabled: _enableCleanup,
          onChanged: (id) {
            setState(() => _selectedProvider = id);
            _settingsService.setProvider(id);
          },
        ),
        MainProviderTile(
          id: 'cloud_providers',
          title: 'Bring Your Own Key',
          subtitle: 'Use your own API key with supported providers.',
          icon: Icons.key_outlined,
          isSelected: _selectedProvider == 'cloud_providers',
          isActive: _selectedProvider == 'cloud_providers',
          groupValue: _selectedProvider,
          enabled: _enableCleanup,
          onChanged: (id) {
            setState(() => _selectedProvider = id);
            _settingsService.setProvider(id);
          },
        ),
        
        if (_selectedProvider == 'cloud_providers') 
          ProviderConfigView(
            selectedCloudProvider: _selectedCloudProvider,
            providers: const ['OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Custom'],
            apiKeyController: _apiKeyController,
            endpointController: _endpointController,
            isLoadingModels: _isLoadingModels,
            isApiKeyVerified: _isApiKeyVerified,
            isBasicValid: ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text),
            modelsLoaded: _modelsLoaded,
            helpUrl: ModelProviderUtils.getApiKeyHelpUrl(_selectedCloudProvider),
            apiKeyPlaceholder: ModelProviderUtils.getApiKeyPlaceholder(_selectedCloudProvider),
            defaultEndpoint: ModelProviderUtils.getEndpointForProvider(_selectedCloudProvider),
            enabled: _enableCleanup,
            onProviderSelected: (p) {
              setState(() {
                _selectedCloudProvider = p;
                _modelsLoaded = false;
                _isApiKeyVerified = false;
              });
              _settingsService.setCloudProvider(p);
              if (ModelProviderUtils.isValidApiKey(p, _apiKeyController.text)) {
                _fetchModels();
              }
            },
            onApiKeyChanged: (val) {
              setState(() {
                _isApiKeyVerified = false;
              });
              if (ModelProviderUtils.isValidApiKey(_selectedCloudProvider, val)) {
                _fetchModels();
              }
            },
            onEndpointChanged: (val) => _settingsService.setEndpoint(val),
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
                            _settingsService.setModel('');
                          }, 
                          child: const Text('Reset')
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: _fetchModels, child: const Text('Refresh')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildModelItem('MiniMax-M2.5', 'minimax'),
                _buildModelItem('Qwen3-30B-A3B', 'custom'),
                _buildModelItem('deepseek-ai/deepseek-v3.2', 'custom'),
                _buildModelItem('deepseek-chat', 'deepseek'),
                _buildModelItem('deepseek-reasoner', 'deepseek'),
                _buildModelItem('gemini-flash-latest', 'vertex-ai'),
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
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedModel = name);
          _settingsService.setModel(name);
        },
        dense: true,
        leading: Radio<String>(
          value: name,
          groupValue: _selectedModel,
          onChanged: (v) {
            setState(() => _selectedModel = v!);
            _settingsService.setModel(v!);
          },
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('Owner: $owner', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
