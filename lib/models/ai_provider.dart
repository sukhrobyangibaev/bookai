enum AiProvider { openRouter, gemini }

extension AiProviderX on AiProvider {
  String get storageValue {
    switch (this) {
      case AiProvider.openRouter:
        return 'openRouter';
      case AiProvider.gemini:
        return 'gemini';
    }
  }

  String get label {
    switch (this) {
      case AiProvider.openRouter:
        return 'OpenRouter';
      case AiProvider.gemini:
        return 'Gemini';
    }
  }
}

AiProvider? aiProviderFromStorage(String? raw) {
  switch (raw?.trim()) {
    case 'openRouter':
      return AiProvider.openRouter;
    case 'gemini':
      return AiProvider.gemini;
    default:
      return null;
  }
}
