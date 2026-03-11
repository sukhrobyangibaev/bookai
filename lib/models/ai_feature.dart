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
  static const askAi = 'ask_ai';
  static const generateImage = 'generate_image';
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
  description: 'Give a short catch-up from selected text or a resume range.',
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
      'Rewrite selected text or a resume range with simpler words and clearer phrasing.',
  defaultPromptTemplate: defaultSimplifyTextPromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{chapter_title}',
    '{source_text}',
  ],
);

const String defaultAskAiPromptTemplate = '''
You are chatting with a reader about a book.

Book: {book_title}
Author: {book_author}
Chapter: {chapter_title}

Passage:
{source_text}

Reader question:
{user_message}

Use the provided passage as context when it is relevant, but the reader may also want to talk more generally about the book.
You may use broader knowledge about the book when it helps answer the question.
If the answer would reveal important spoilers, warn the reader before giving the spoiler-sensitive part of the answer.
Be clear, direct, and helpful.
''';

const AiFeatureDefinition askAiFeature = AiFeatureDefinition(
  id: AiFeatureIds.askAi,
  title: 'Ask AI',
  description:
      'Answer reader questions about selected text or a resume range, with follow-up chat.',
  defaultPromptTemplate: defaultAskAiPromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{book_author}',
    '{chapter_title}',
    '{source_text}',
    '{user_message}',
  ],
);

const String defaultDefineAndTranslatePromptTemplate = '''
You will be given selected text from a book. It may be a word, a phrase, or a character name.

Book: {book_title}
Author: {book_author}

Selected text:
{source_text}

Context sentence:
{context_sentence}

Respond briefly in exactly two parts:
1. Definition: give a short, plain explanation of the selected text in English. If it is a phrase, explain the phrase naturally instead of treating each word separately. If it is a character name, identify who the character is only in spoiler-safe terms based on the provided context.
2. Translation: translate the selected text into Russian.

Use the context sentence to disambiguate meaning when needed.
Never include spoilers.
Only use information that is explicit in the selected text and context sentence.
Do not mention future events, hidden motives, later relationships, twists, backstory not shown here, or anything a reader would learn later in the book.
Keep the answer concise and useful for a reader.
''';

const AiFeatureDefinition defineAndTranslateFeature = AiFeatureDefinition(
  id: AiFeatureIds.defineAndTranslate,
  title: 'Define & Translate',
  description:
      'Explain the selected text and translate it using the prompt language.',
  defaultPromptTemplate: defaultDefineAndTranslatePromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{book_author}',
    '{context_sentence}',
    '{source_text}',
  ],
);

const String defaultGenerateImagePromptTemplate = '''
You are creating an image-generation prompt for a scene from a book.

Book: {book_title}
Author: {book_author}
Chapter: {chapter_title}

Selected passage:
{source_text}

Context sentence:
{context_sentence}

Write one vivid, spoiler-safe prompt for an illustration of this exact moment.
Base it only on details that are explicit in the passage or context sentence.
Describe the important subject, setting, mood, lighting, composition, clothing, and notable objects when they are available.
Do not mention text overlays, page layouts, watermarks, artist names, or camera brands.
Return only the final image prompt.
''';

const AiFeatureDefinition generateImageFeature = AiFeatureDefinition(
  id: AiFeatureIds.generateImage,
  title: 'Generate Image',
  description:
      'Turn the selected text or resume range into an editable image prompt.',
  defaultPromptTemplate: defaultGenerateImagePromptTemplate,
  placeholders: <String>[
    '{book_title}',
    '{book_author}',
    '{chapter_title}',
    '{context_sentence}',
    '{source_text}',
  ],
);

const List<AiFeatureDefinition> aiFeatures = <AiFeatureDefinition>[
  resumeSummaryFeature,
  simplifyTextFeature,
  askAiFeature,
  defineAndTranslateFeature,
  generateImageFeature,
];

const Map<String, AiFeatureConfig> defaultAiFeatureConfigs =
    <String, AiFeatureConfig>{
  AiFeatureIds.resumeSummary: AiFeatureConfig(
    promptTemplate: defaultResumeSummaryPromptTemplate,
  ),
  AiFeatureIds.simplifyText: AiFeatureConfig(
    promptTemplate: defaultSimplifyTextPromptTemplate,
  ),
  AiFeatureIds.askAi: AiFeatureConfig(
    promptTemplate: defaultAskAiPromptTemplate,
  ),
  AiFeatureIds.defineAndTranslate: AiFeatureConfig(
    promptTemplate: defaultDefineAndTranslatePromptTemplate,
  ),
  AiFeatureIds.generateImage: AiFeatureConfig(
    promptTemplate: defaultGenerateImagePromptTemplate,
  ),
};

AiFeatureDefinition? aiFeatureById(String id) {
  for (final feature in aiFeatures) {
    if (feature.id == id) return feature;
  }
  return null;
}
