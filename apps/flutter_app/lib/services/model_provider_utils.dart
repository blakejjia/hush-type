class ModelProviderUtils {
  static const String anthropicVersion = '2023-06-01';

  static bool isValidApiKey(String provider, String key) {
    return getApiKeyValidationError(provider, key) == null;
  }

  static String? getApiKeyValidationError(String provider, String key) {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) {
      return null;
    }

    switch (provider) {
      case 'OpenAI':
        if (!RegExp(r'^sk-[A-Za-z0-9_-]{20,}$').hasMatch(trimmedKey)) {
          return 'OpenAI keys should look like sk-...';
        }
        return null;
      case 'Anthropic':
        if (!RegExp(r'^sk-ant-[A-Za-z0-9_-]{20,}$').hasMatch(trimmedKey)) {
          return 'Anthropic keys should look like sk-ant-...';
        }
        return null;
      case 'Google Gemini':
        if (!RegExp(r'^AIza[0-9A-Za-z_-]{20,}$').hasMatch(trimmedKey)) {
          return 'Gemini keys should look like AIza...';
        }
        return null;
      case 'Groq':
        if (!RegExp(r'^gsk_[A-Za-z0-9_-]{20,}$').hasMatch(trimmedKey)) {
          return 'Groq keys should look like gsk_...';
        }
        return null;
      case 'Mistral':
        if (!RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(trimmedKey)) {
          return 'Mistral keys should be a long token from the console.';
        }
        return null;
      case 'Custom':
        if (trimmedKey.length < 6) {
          return 'Enter a longer API key.';
        }
        return null;
      default:
        if (trimmedKey.length < 6) {
          return 'Enter a longer API key.';
        }
        return null;
    }
  }

  static String getApiKeyPlaceholder(String provider) {
    switch (provider) {
      case 'OpenAI': return 'sk-...';
      case 'Anthropic': return 'sk-ant-...';
      case 'Google Gemini': return 'AIza...';
      case 'Groq': return 'gsk_...';
      case 'Mistral': return 'Paste your API key here';
      default: return 'Enter your API key';
    }
  }

  static String getApiKeyHelpUrl(String provider) {
    switch (provider) {
      case 'OpenAI': return 'https://platform.openai.com/api-keys';
      case 'Anthropic': return 'https://console.anthropic.com/settings/keys';
      case 'Google Gemini': return 'https://aistudio.google.com/app/apikey';
      case 'Groq': return 'https://console.groq.com/keys';
      case 'Mistral': return 'https://console.mistral.ai/api-keys/';
      default: return '';
    }
  }

  static String getEndpointForProvider(String provider, {bool isSTT = false}) {
    if (isSTT) {
      switch (provider) {
        case 'OpenAI': return 'https://api.openai.com/v1/audio/transcriptions';
        case 'Groq': return 'https://api.groq.com/openai/v1/audio/transcriptions';
        case 'Mistral': return 'https://api.mistral.ai/v1/audio/transcriptions';
        default: return '';
      }
    } else {
      switch (provider) {
        case 'OpenAI': return 'https://api.openai.com/v1';
        case 'Anthropic': return 'https://api.anthropic.com/v1';
        case 'Google Gemini': return 'https://generativelanguage.googleapis.com/v1beta';
        case 'Groq': return 'https://api.groq.com/openai/v1';
        default: return '';
      }
    }
  }

  static String buildModelsEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return '';
    }

    final normalized = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;

    if (normalized.endsWith('/models')) {
      return normalized;
    }

    if (normalized.endsWith('/audio/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/audio/transcriptions'.length)}/models';
    }

    if (normalized.endsWith('/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/transcriptions'.length)}/models';
    }

    return '$normalized/models';
  }
}
