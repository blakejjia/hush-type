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
  
  bool _modelsLoaded = false;
  bool _isLoadingModels = false;
  bool _isApiKeyVerified = false;
  List<ApiModel> _availableModels = [];

  void _fetchModels() async {
    if (!ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text)) return;
    
    await _settingsService.setApiKey(_apiKeyController.text);
    setState(() {
      _isLoadingModels = true;
      _modelsLoaded = false;
      _isApiKeyVerified = false;
    });
    
    final models = await _settingsService.fetchAvailableModels();
    
    if (mounted) {
      setState(() {
        _isLoadingModels = false;
        _availableModels = models;
        _modelsLoaded = models.isNotEmpty;
        _isApiKeyVerified = models.isNotEmpty;
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settingsService.getProvider();
    final cloudProvider = await _settingsService.getCloudProvider();
    final model = await _settingsService.getModel();
    final apiKey = await _settingsService.getApiKey();
    final endpoint = await _settingsService.getEndpoint();

    if (mounted) {
      setState(() {
        _selectedProvider = provider;
        _selectedCloudProvider = cloudProvider;
        _selectedModel = model;
        _apiKeyController.text = apiKey;
        _endpointController.text = endpoint;
        
        if (ModelProviderUtils.isValidApiKey(cloudProvider, apiKey)) {
          _fetchModels();
        }
      });
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
            isLoadingModels: _isLoadingModels,
            isApiKeyVerified: _isApiKeyVerified,
            isBasicValid: ModelProviderUtils.isValidApiKey(_selectedCloudProvider, _apiKeyController.text),
            modelsLoaded: _modelsLoaded,
            helpUrl: ModelProviderUtils.getApiKeyHelpUrl(_selectedCloudProvider),
            apiKeyPlaceholder: ModelProviderUtils.getApiKeyPlaceholder(_selectedCloudProvider),
            defaultEndpoint: ModelProviderUtils.getEndpointForProvider(_selectedCloudProvider, isSTT: true),
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
                    child: Center(child: Text('No Whisper models found.', style: TextStyle(color: Colors.red))),
                  )
                else
                  RadioGroup<String>(
                    groupValue: _selectedModel,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedModel = v);
                      _settingsService.setModel(v);
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
          _settingsService.setModel(name);
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
