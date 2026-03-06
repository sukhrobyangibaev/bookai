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
Give a brief reading catch-up for someone continuing the same book.

Book: {book_title}
Chapter: {chapter_title}

Do not write a full summary.
In 2-4 short sentences, explain what is going on at this point.
The passage may be a single paragraph or a whole chapter, so focus on the most important developments, character actions, and changes that matter for continuing.
Use simple words and short, plain sentences.
Avoid long recaps, analysis, and unnecessary detail.

Passage:
{source_text}
''';

const AiFeatureDefinition resumeSummaryFeature = AiFeatureDefinition(
  id: AiFeatureIds.resumeSummary,
  title: 'Resume Here and Catch Me Up',
  description: 'Give a short catch-up from the previous resume point.',
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
