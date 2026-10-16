import 'document_store.dart';
import 'errors.dart';

const defaultPreferences = <String, dynamic>{
  'compact': false,
  'theme': 'system',
  'chatTextSize': 'normal',
  'chatAssistant': 'last',
  'chatStreaming': true,
  'chatShowTimestamps': false,
  'chatDateFormat': 'dd/MM/yyyy',
  'aiPreset': 'balanced',
  'aiTemperature': 0.25,
  'aiMaxTokens': 1200,
  'aiReasoning': false,
  'aiResponseMode': 'balanced',
  'aiDepth': 'normal',
  'aiUseContext': true,
};

Document validatePreferences(Document previous, Document changes) {
  final result = {...defaultPreferences, ...previous};
  const choices = {
    'theme': ['system', 'light', 'dark'],
    'chatTextSize': ['small', 'normal', 'large'],
    'chatAssistant': ['last', 'standard', 'rag'],
    'chatDateFormat': ['dd/MM/yyyy', 'yyyy-MM-dd'],
    'aiPreset': ['precise', 'balanced', 'explanatory', 'deep'],
    'aiResponseMode': ['concise', 'balanced', 'detailed'],
    'aiDepth': ['normal', 'deep'],
  };
  for (final entry in changes.entries) {
    final key = entry.key, value = entry.value;
    if (!defaultPreferences.containsKey(key)) {
      throw ApiError(400, 'Preferência desconhecida: $key.');
    }
    final valid = switch (key) {
      'compact' ||
      'chatStreaming' ||
      'chatShowTimestamps' ||
      'aiReasoning' ||
      'aiUseContext' => value is bool,
      'aiTemperature' =>
        value is num && value.isFinite && value >= 0 && value <= 1,
      'aiMaxTokens' => value is int && [600, 1200, 2400, 4096].contains(value),
      _ => choices[key]?.contains(value) == true,
    };
    if (!valid) throw ApiError(400, 'Valor inválido para $key.');
    result[key] = value;
  }
  return result;
}

Document aiPreferences(Document prefs) => {
  'assistant': prefs['chatAssistant'],
  'preset': prefs['aiPreset'],
  'temperature': prefs['aiTemperature'],
  'max_output_tokens': prefs['aiMaxTokens'],
  'reasoning': prefs['aiReasoning'],
  'response_mode': prefs['aiResponseMode'],
  'analysis_depth': prefs['aiDepth'],
  'use_context': prefs['aiUseContext'],
  'streaming': prefs['chatStreaming'],
};
