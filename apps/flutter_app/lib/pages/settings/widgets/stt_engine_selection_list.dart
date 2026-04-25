import 'package:flutter/material.dart';
import '../../../services/stt_settings_service.dart';

class STTEngineSelectionList extends StatefulWidget {
  const STTEngineSelectionList({super.key});

  @override
  State<STTEngineSelectionList> createState() => _STTEngineSelectionListState();
}

class _STTEngineSelectionListState extends State<STTEngineSelectionList> {
  final STTSettingsService _settingsService = STTSettingsService();
  String _selectedProvider = 'cloud_providers';
  String _selectedCloudProvider = 'OpenAI';
  String _selectedModel = 'Whisper Large v3';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  
  bool _modelsLoaded = false;
  bool _isLoadingModels = false;

  void _fetchModels() async {
    if (!_isValidApiKey(_selectedCloudProvider, _apiKeyController.text)) return;
    
    _settingsService.setApiKey(_apiKeyController.text);
    setState(() {
      _isLoadingModels = true;
      _modelsLoaded = false;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isLoadingModels = false;
        _modelsLoaded = true;
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
        
        if (_isValidApiKey(cloudProvider, apiKey)) {
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
        _buildMainProviderTile(
          context,
          id: 'cloud',
          title: 'Cloud',
          subtitle: 'Reliable accuracy. No setup needed.',
          icon: Icons.cloud_outlined,
          isActive: _selectedProvider == 'cloud',
        ),
        _buildMainProviderTile(
          context,
          id: 'cloud_providers',
          title: 'Bring Your Own Key',
          subtitle: 'Use your own API key with supported providers.',
          icon: Icons.key_outlined,
          isActive: _selectedProvider == 'cloud_providers',
        ),
        if (_selectedProvider == 'cloud_providers') _buildCloudProviderDetails(context),
      ],
    );
  }

  Widget _buildMainProviderTile(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isActive = false,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedProvider == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: enabled ? () {
          setState(() => _selectedProvider = id);
          _settingsService.setProvider(id);
        } : null,
        leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Active', style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        subtitle: Text(subtitle),
        trailing: Radio<String>(
          value: id,
          groupValue: _selectedProvider,
          onChanged: enabled ? (v) {
            setState(() => _selectedProvider = v!);
            _settingsService.setProvider(v!);
          } : null,
        ),
      ),
    );
  }

  String _getEndpointForSTTProvider(String provider) {
    switch (provider) {
      case 'OpenAI': return 'https://api.openai.com/v1/audio/transcriptions';
      case 'Groq': return 'https://api.groq.com/openai/v1/audio/transcriptions';
      case 'Mistral': return 'https://api.mistral.ai/v1/audio/transcriptions';
      default: return '';
    }
  }

  String _getApiKeyPlaceholder(String provider) {
    switch (provider) {
      case 'OpenAI': return 'sk-...';
      case 'Groq': return 'gsk_...';
      case 'Mistral': return 'Paste your Mistral API key here';
      default: return 'Enter your API key';
    }
  }

  String _getApiKeyHelpUrl(String provider) {
    switch (provider) {
      case 'OpenAI': return 'https://platform.openai.com/api-keys';
      case 'Groq': return 'https://console.groq.com/keys';
      case 'Mistral': return 'https://console.mistral.ai/api-keys/';
      default: return '';
    }
  }

  bool _isValidApiKey(String provider, String key) {
    if (key.isEmpty) return false;
    switch (provider) {
      case 'OpenAI':
        return RegExp(r'^sk-[a-zA-Z0-9]{32,}$').hasMatch(key);
      case 'Groq':
        return RegExp(r'^gsk_[a-zA-Z0-9]{32,}$').hasMatch(key);
      case 'Mistral':
        return RegExp(r'^[a-zA-Z0-9]{32,}$').hasMatch(key);
      default:
        return key.length > 5;
    }
  }

  Widget _buildCloudProviderDetails(BuildContext context) {
    final providers = ['OpenAI', 'Groq', 'Mistral', 'Custom'];
    final defaultEndpoint = _getEndpointForSTTProvider(_selectedCloudProvider);
    final helpUrl = _getApiKeyHelpUrl(_selectedCloudProvider);
    final isValid = _isValidApiKey(_selectedCloudProvider, _apiKeyController.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: providers.map((p) {
                final isSelected = _selectedCloudProvider == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    onSelected: (v) {
                      setState(() {
                        _selectedCloudProvider = p;
                        _modelsLoaded = false;
                      });
                      _settingsService.setCloudProvider(p);
                      if (_isValidApiKey(p, _apiKeyController.text)) {
                        _fetchModels();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_selectedCloudProvider == 'Custom') ...[
            const Text('Endpoint URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _endpointController,
              onChanged: (val) => _settingsService.setEndpoint(val),
              decoration: InputDecoration(
                hintText: 'https://yourendpoint.com/v1/audio/transcriptions',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text('Default Endpoint: $defaultEndpoint', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (helpUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    // In a real app, use url_launcher
                  },
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Get Key', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            onChanged: (val) {
              setState(() {}); // Trigger validation update
              if (_isValidApiKey(_selectedCloudProvider, val)) {
                _fetchModels();
              }
            },
            decoration: InputDecoration(
              hintText: _getApiKeyPlaceholder(_selectedCloudProvider),
              prefixIcon: const Icon(Icons.key, size: 18),
              errorText: _apiKeyController.text.isNotEmpty && !isValid 
                  ? 'Invalid API key format for $_selectedCloudProvider' 
                  : null,
              suffixIcon: _isLoadingModels 
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (isValid ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          
          if (_modelsLoaded) ...[
            const Text('Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _buildModelTile('whisper-1', 'High accuracy speech recognition', _selectedModel == 'whisper-1'),
            _buildModelTile('whisper-large-v3', 'Open source version', _selectedModel == 'whisper-large-v3'),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Enter API key to fetch available models.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelTile(String name, String desc, bool active) {
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
