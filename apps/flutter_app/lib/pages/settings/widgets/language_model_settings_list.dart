import 'package:flutter/material.dart';
import '../../../services/llm_settings_service.dart';

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
        
        if (_isValidApiKey(cloudProvider, apiKey)) {
          _fetchModels();
        }
      });
    }
  }

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
        enabled: _enableCleanup,
        onTap: () {
          setState(() => _selectedProvider = id);
          _settingsService.setProvider(id);
        },
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
          onChanged: _enableCleanup ? (v) {
            setState(() => _selectedProvider = v!);
            _settingsService.setProvider(v!);
          } : null,
        ),
      ),
    );
  }

  String _getEndpointForProvider(String provider) {
    switch (provider) {
      case 'OpenAI': return 'https://api.openai.com/v1';
      case 'Anthropic': return 'https://api.anthropic.com/v1';
      case 'Google Gemini': return 'https://generativelanguage.googleapis.com/v1beta';
      case 'Groq': return 'https://api.groq.com/openai/v1';
      default: return '';
    }
  }

  String _getApiKeyPlaceholder(String provider) {
    switch (provider) {
      case 'OpenAI': return 'sk-...';
      case 'Anthropic': return 'sk-ant-...';
      case 'Google Gemini': return 'AIza...';
      case 'Groq': return 'gsk_...';
      default: return 'Enter your API key';
    }
  }

  String _getApiKeyHelpUrl(String provider) {
    switch (provider) {
      case 'OpenAI': return 'https://platform.openai.com/api-keys';
      case 'Anthropic': return 'https://console.anthropic.com/settings/keys';
      case 'Google Gemini': return 'https://aistudio.google.com/app/apikey';
      case 'Groq': return 'https://console.groq.com/keys';
      default: return '';
    }
  }

  bool _isValidApiKey(String provider, String key) {
    if (key.isEmpty) return false;
    switch (provider) {
      case 'OpenAI':
        return RegExp(r'^sk-[a-zA-Z0-9]{32,}$').hasMatch(key);
      case 'Anthropic':
        return RegExp(r'^sk-ant-[a-zA-Z0-9-]{32,}$').hasMatch(key);
      case 'Google Gemini':
        return RegExp(r'^AIza[a-zA-Z0-9_-]{35}$').hasMatch(key);
      case 'Groq':
        return RegExp(r'^gsk_[a-zA-Z0-9]{32,}$').hasMatch(key);
      default:
        return key.length > 5;
    }
  }

  Widget _buildCloudProviderDetails(BuildContext context) {
    final providers = ['OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Custom'];
    final defaultEndpoint = _getEndpointForProvider(_selectedCloudProvider);
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
              enabled: _enableCleanup,
              onChanged: (val) => _settingsService.setEndpoint(val),
              decoration: InputDecoration(
                hintText: 'https://yourendpoint.com/v1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Examples: http://localhost:11434/v1 (Ollama), http://localhost:8080/v1 (LocalAI).', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
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
            enabled: _enableCleanup,
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
