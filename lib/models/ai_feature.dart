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
  static const defineAndTranslate = 'define_and_translate';
  static const simplifyText = 'simplify_text';
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

const String defaultSimplifyTextPromptTemplate = '''
Rewrite the passage below so it is easier to understand.

Book: {book_title}
Chapter: {chapter_title}

Do not summarize, shorten, or omit important information.
Keep the original meaning, events, and details.
Use simpler words, clearer phrasing, and shorter sentences where helpful.
Return only the rewritten passage.

Passage:
{source_text}
''';

const AiFeatureDefinition simplifyTextFeature = AiFeatureDefinition(
  id: AiFeatureIds.simplifyText,
  title: 'Simplify Text',
  description:
      'Rewrite the selected resume range with simpler words and clearer phrasing.',
  defaultPromptTemplate: defaultSimplifyTextPromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{chapter_title}',
    '{source_text}',
  ],
);

const String defaultDefineAndTranslatePromptTemplate = '''
You will be given a selected word or phrase from a book.

Book: {book_title}
Author: {book_author}

Selected text:
{source_text}

Context sentence:
{context_sentence}

Respond briefly in exactly two parts:
1. Definition: give a short, plain explanation of the selected text in English. If it is a phrase, explain the phrase naturally instead of treating each word separately.
2. Translation: translate the selected text into Russian.

Use the context sentence to disambiguate meaning when needed.
Keep the answer concise and useful for a reader.
''';

const AiFeatureDefinition defineAndTranslateFeature = AiFeatureDefinition(
  id: AiFeatureIds.defineAndTranslate,
  title: 'Define & Translate',
  description:
      'Explain the selected word or phrase and translate it using the prompt language.',
  defaultPromptTemplate: defaultDefineAndTranslatePromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{book_author}',
    '{context_sentence}',
    '{source_text}',
  ],
);

const List<AiFeatureDefinition> aiFeatures = <AiFeatureDefinition>[
  resumeSummaryFeature,
  simplifyTextFeature,
  defineAndTranslateFeature,
];

const Map<String, AiFeatureConfig> defaultAiFeatureConfigs =
    <String, AiFeatureConfig>{
  AiFeatureIds.resumeSummary: AiFeatureConfig(
    promptTemplate: defaultResumeSummaryPromptTemplate,
  ),
  AiFeatureIds.simplifyText: AiFeatureConfig(
    promptTemplate: defaultSimplifyTextPromptTemplate,
  ),
  AiFeatureIds.defineAndTranslate: AiFeatureConfig(
    promptTemplate: defaultDefineAndTranslatePromptTemplate,
  ),
};

AiFeatureDefinition? aiFeatureById(String id) {
  for (final feature in aiFeatures) {
    if (feature.id == id) return feature;
  }
  return null;
}
