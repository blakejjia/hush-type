import 'package:flutter/material.dart';
import '../../../services/llm_settings_service.dart';
import '../../../services/ai_provider_registry.dart';
import 'shared/settings_common_widgets.dart';
import 'shared/provider_settings_controller.dart';

class LanguageModelSettingsList extends StatefulWidget {
  final String title;
  const LanguageModelSettingsList({super.key, required this.title});

  @override
  State<LanguageModelSettingsList> createState() => _LanguageModelSettingsListState();
}

class _LanguageModelSettingsListState extends State<LanguageModelSettingsList> {
  final LLMSettingsService _settingsService = LLMSettingsService();
  bool _enableCleanup = true;
  final TextEditingController _promptController = TextEditingController();
  late final ProviderSettingsController _providerController;

  @override
  void initState() {
    super.initState();
    _providerController = ProviderSettingsController(settingsService: _settingsService)
      ..addListener(_onProviderStateChanged);
    _loadSettings();
  }

  void _onProviderStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    final enabled = await _settingsService.isEnabled();
    final prompt = await _settingsService.getSystemPrompt();
    await _providerController.load();

    if (mounted) {
      setState(() {
        _enableCleanup = enabled;
        _promptController.text = prompt;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _providerController
      ..removeListener(_onProviderStateChanged)
      ..dispose();
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
          groupValue: _providerController.selectedProvider,
          onChanged: (id) {
            if (!_enableCleanup || id == null) return;
            _providerController.setProviderMode(id);
          },
          child: Column(
            children: [
              MainProviderTile(
                id: 'cloud',
                title: 'Cloud',
                subtitle: 'Reliable accuracy. (Not ready yet)',
                icon: Icons.cloud_outlined,
                isSelected: _providerController.selectedProvider == 'cloud',
                isActive: _providerController.selectedProvider == 'cloud',
                enabled: false,
                showComingSoon: true,
              ),
              MainProviderTile(
                id: 'cloud_providers',
                title: 'Bring Your Own Key',
                subtitle: 'Use your own API key with supported providers.',
                icon: Icons.key_outlined,
                isSelected: _providerController.selectedProvider == 'cloud_providers',
                isActive: _providerController.selectedProvider == 'cloud_providers',
                enabled: _enableCleanup,
              ),
            ],
          ),
        ),
        
        if (_providerController.selectedProvider == 'cloud_providers') 
          ProviderConfigView(
            selectedCloudProvider: _providerController.selectedCloudProvider,
            providers: AiProviderRegistry.providersFor(AiProviderFeature.llm),
            apiKeyController: _providerController.apiKeyController,
            endpointController: _providerController.endpointController,
            apiKeyFocusNode: _providerController.apiKeyFocusNode,
            isLoadingModels: _providerController.isLoadingModels,
            isApiKeyVerified: _providerController.isApiKeyVerified,
            isBasicValid: _providerController.isBasicValid,
            modelsLoaded: _providerController.modelsLoaded,
            errorText: _providerController.errorText,
            helpUrl: _providerController.helpUrl,
            apiKeyPlaceholder: _providerController.apiKeyPlaceholder,
            defaultEndpoint: _providerController.defaultEndpoint,
            enabled: _enableCleanup,
            onProviderSelected: (p) => _providerController.selectCloudProvider(p),
            onApiKeyChanged: (val) => _providerController.updateApiKey(val),
            onEndpointChanged: (val) => _providerController.updateEndpoint(val),
            onClearApiKey: () => _providerController.clearApiKey(),
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
                            _providerController.resetModel();
                          }, 
                          child: const Text('Reset')
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _providerController.isLoadingModels
                              ? null
                              : _providerController.fetchModels,
                          child: const Text('Refresh')
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_providerController.availableModels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No models found from this endpoint.', style: TextStyle(color: Colors.red))),
                  )
                else
                  RadioGroup<String>(
                    groupValue: _providerController.selectedModel,
                    onChanged: (v) {
                      if (v == null) return;
                      _providerController.selectModel(v);
                    },
                    child: Column(
                      children: _providerController.availableModels
                          .map((m) => _buildModelItem(m.id, m.ownedBy))
                          .toList(),
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
    final isSelected = _providerController.selectedModel == name;

    return Card(
      key: ValueKey(name),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () {
          _providerController.selectModel(name);
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
