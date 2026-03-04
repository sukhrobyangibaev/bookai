import 'ai_feature_config.dart';

class AiFeatureDefinition {
  final String id;
  final String title;
  final String description;
  final String defaultPromptTemplate;
  final List<String> placeholders;

  const AiFeatureDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.defaultPromptTemplate,
    required this.placeholders,
  });
}

class AiFeatureIds {
  static const resumeSummary = 'resume_summary';
}

const String defaultResumeSummaryPromptTemplate = '''
Summarize the provided passage for someone continuing to read the same book.

Book: {book_title}
Chapter: {chapter_title}

Focus on key points, character actions, and context needed to continue.
Keep it concise and clear.

Passage:
{source_text}
''';

const AiFeatureDefinition resumeSummaryFeature = AiFeatureDefinition(
  id: AiFeatureIds.resumeSummary,
  title: 'Resume Here and Summarize',
  description: 'Summarize from the previous resume point to selected text.',
  defaultPromptTemplate: defaultResumeSummaryPromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{chapter_title}',
    '{source_text}',
  ],
);

const List<AiFeatureDefinition> aiFeatures = <AiFeatureDefinition>[
  resumeSummaryFeature,
];

const Map<String, AiFeatureConfig> defaultAiFeatureConfigs =
    <String, AiFeatureConfig>{
  AiFeatureIds.resumeSummary: AiFeatureConfig(
    promptTemplate: defaultResumeSummaryPromptTemplate,
  ),
};

AiFeatureDefinition? aiFeatureById(String id) {
  for (final feature in aiFeatures) {
    if (feature.id == id) return feature;
  }
  return null;
}
