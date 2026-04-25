class ModelProviderUtils {
  static bool isValidApiKey(String provider, String key) {
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
      case 'Mistral':
        return RegExp(r'^[a-zA-Z0-9]{32,}$').hasMatch(key);
      default:
        return key.length > 5;
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
}
