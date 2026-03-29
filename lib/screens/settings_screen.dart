import 'package:flutter/material.dart';

import '../app.dart';
import '../models/ai_feature.dart';
import '../models/ai_feature_config.dart';
import '../models/ai_model_info.dart';
import '../models/ai_model_selection.dart';
import '../models/ai_provider.dart';
import '../models/reader_settings.dart';
import '../services/gemini_service.dart';
import '../services/openrouter_service.dart';
import '../services/settings_controller.dart';
import '../theme/reader_typography.dart';
import '../widgets/mobile_scrollbar.dart';

class SettingsScreen extends StatefulWidget {
  final OpenRouterService? openRouterService;
  final GeminiService? geminiService;

  const SettingsScreen({
    super.key,
    this.openRouterService,
    this.geminiService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<AppThemeMode> _themeModes = <AppThemeMode>[
    AppThemeMode.system,
    AppThemeMode.light,
    AppThemeMode.dark,
    AppThemeMode.night,
    AppThemeMode.sepia,
  ];

  late final TextEditingController _openRouterApiKeyController;
  late final TextEditingController _geminiApiKeyController;
  late final OpenRouterService _openRouterService;
  late final GeminiService _geminiService;
  final ScrollController _scrollController = ScrollController();
  bool _obscureOpenRouterApiKey = true;
  bool _obscureGeminiApiKey = true;
  SettingsController? _controllerForSync;

  @override
  void initState() {
    super.initState();
    _openRouterApiKeyController = TextEditingController();
    _geminiApiKeyController = TextEditingController();
    _openRouterService = widget.openRouterService ?? OpenRouterService();
    _geminiService = widget.geminiService ?? GeminiService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = SettingsControllerScope.of(context);
    if (_controllerForSync != controller) {
      _controllerForSync?.removeListener(_syncApiKeyFields);
      _controllerForSync = controller;
      _controllerForSync!.addListener(_syncApiKeyFields);
      _syncApiKeyFields();
    }
  }

  @override
  void dispose() {
    _controllerForSync?.removeListener(_syncApiKeyFields);
    _openRouterApiKeyController.dispose();
    _geminiApiKeyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncApiKeyFields() {
    final controller = _controllerForSync;
    if (controller == null) return;

    _syncApiKeyController(
      controller: _openRouterApiKeyController,
      value: controller.openRouterApiKey,
    );
    _syncApiKeyController(
      controller: _geminiApiKeyController,
      value: controller.geminiApiKey,
    );
  }

  void _syncApiKeyController({
    required TextEditingController controller,
    required String value,
  }) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  Future<List<AiModelInfo>> _loadModelsForProvider({
    required AiProvider provider,
    required String apiKey,
    bool forceRefresh = false,
  }) {
    switch (provider) {
      case AiProvider.openRouter:
        return _openRouterService.fetchModelInfos(
          apiKey: apiKey,
          forceRefresh: forceRefresh,
        );
      case AiProvider.gemini:
        return _geminiService.fetchModels(
          apiKey: apiKey,
          forceRefresh: forceRefresh,
        );
    }
  }

  Future<AiModelSelection?> _pickModelSelection({
    required BuildContext context,
    required SettingsController controller,
    required AiModelSelection selectedSelection,
    required String title,
    required String requiredOutputModality,
  }) async {
    AiModelSelection? pickedSelection;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _AiProviderModelPickerSheet(
            title: title,
            selectedSelection: selectedSelection,
            requiredOutputModality: requiredOutputModality,
            apiKeyForProvider: controller.apiKeyForProvider,
            loadModels: ({
              required AiProvider provider,
              bool forceRefresh = false,
            }) {
              return _loadModelsForProvider(
                provider: provider,
                apiKey: controller.apiKeyForProvider(provider),
                forceRefresh: forceRefresh,
              );
            },
            onModelSelected: (selection) {
              pickedSelection = selection;
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
    return pickedSelection;
  }

  Future<void> _showModelPicker(
    BuildContext context,
    SettingsController controller,
  ) async {
    final selection = await _pickModelSelection(
      context: context,
      controller: controller,
      selectedSelection: controller.defaultModelSelection,
      title: 'Choose Default Model',
      requiredOutputModality: 'text',
    );
    if (selection == null) return;
    await controller.setDefaultModelSelection(selection);
  }

  Future<void> _showFallbackModelPicker(
    BuildContext context,
    SettingsController controller,
  ) async {
    final selection = await _pickModelSelection(
      context: context,
      controller: controller,
      selectedSelection: controller.fallbackModelSelection,
      title: 'Choose Fallback Model',
      requiredOutputModality: 'text',
    );
    if (selection == null) return;
    await controller.setFallbackModelSelection(selection);
  }

  Future<void> _showImageModelPicker(
    BuildContext context,
    SettingsController controller,
  ) async {
    final selection = await _pickModelSelection(
      context: context,
      controller: controller,
      selectedSelection: controller.imageModelSelection,
      title: 'Choose Image Model',
      requiredOutputModality: 'image',
    );
    if (selection == null) return;
    await controller.setImageModelSelection(selection);
  }

  Future<void> _showFeatureConfigSheet(
    BuildContext context,
    SettingsController controller,
    AiFeatureDefinition feature,
  ) async {
    final initialConfig = controller.aiFeatureConfig(feature.id);
    final promptController = TextEditingController(
      text: initialConfig.promptTemplate,
    );
    bool useGlobalModel = !initialConfig.modelOverride.isConfigured;
    AiModelSelection modelOverride = initialConfig.modelOverride;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final effectiveModelLabel = useGlobalModel
                ? _selectionSubtitle(
                    controller.defaultModelSelection,
                    emptyLabel: 'No global default model selected',
                  )
                : _selectionSubtitle(
                    modelOverride,
                    emptyLabel: 'No model override selected',
                  );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feature.description,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use global default model'),
                      value: useGlobalModel,
                      onChanged: (value) {
                        setSheetState(() {
                          useGlobalModel = value;
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Model'),
                      subtitle: Text(
                        effectiveModelLabel,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.search),
                      onTap: useGlobalModel
                          ? null
                          : () async {
                              final selected = await _pickModelSelection(
                                context: sheetContext,
                                controller: controller,
                                selectedSelection: modelOverride,
                                title: 'Choose Prompt Model Override',
                                requiredOutputModality: 'text',
                              );
                              if (selected == null) return;
                              setSheetState(() {
                                modelOverride = selected;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: promptController,
                      maxLines: 8,
                      minLines: 6,
                      decoration: InputDecoration(
                        labelText: 'Prompt Template',
                        border: const OutlineInputBorder(),
                        helperText:
                            'Supported placeholders: ${feature.placeholders.join(', ')}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            promptController.text =
                                feature.defaultPromptTemplate;
                          },
                          child: const Text('Reset Prompt'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            await controller.setAiFeatureConfig(
                              feature.id,
                              AiFeatureConfig(
                                modelOverride: useGlobalModel
                                    ? AiModelSelection.none
                                    : modelOverride,
                                promptTemplate: promptController.text,
                              ),
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    promptController.dispose();
  }

  String _selectionSubtitle(
    AiModelSelection selection, {
    required String emptyLabel,
  }) {
    if (!selection.isConfigured) return emptyLabel;
    return '${selection.provider!.label} · ${selection.normalizedModelId}';
  }

  String _featureModelLabel(
    AiModelSelection selection, {
    required bool usesGlobalModel,
  }) {
    if (usesGlobalModel) {
      return selection.isConfigured
          ? 'Prompt model: Global default ${selection.provider!.label} · ${selection.normalizedModelId}'
          : 'Prompt model: Global default not set';
    }

    return selection.isConfigured
        ? 'Prompt model: Override ${selection.provider!.label} · ${selection.normalizedModelId}'
        : 'Prompt model: Override not set';
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsControllerScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return MobileScrollbar(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildFontSection(context, controller),
                const Divider(height: 32),
                _buildFontSizeSection(context, controller),
                const Divider(height: 32),
                _buildThemeSection(context, controller),
                const Divider(height: 32),
                _buildAiSection(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFontSection(
    BuildContext context,
    SettingsController controller,
  ) {
    final currentFont = controller.fontFamily;
    final labelStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fontFamily in ReaderFontFamily.values)
                ChoiceChip(
                  label: Text(
                    fontFamily.label,
                    style: applyReaderFont(
                      baseStyle: labelStyle,
                      fontFamily: fontFamily,
                    ),
                  ),
                  selected: currentFont == fontFamily,
                  onSelected: (selected) {
                    if (!selected) return;
                    controller.setFontFamily(fontFamily);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSection(
    BuildContext context,
    SettingsController controller,
  ) {
    final fontSize = controller.fontSize;
    final previewStyle = applyReaderFont(
      baseStyle: TextStyle(fontSize: fontSize, height: 1.6),
      fontFamily: controller.fontFamily,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  label: fontSize.round().toString(),
                  onChanged: (value) => controller.setFontSize(value),
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 28)),
            ],
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Preview text in ${controller.fontFamily.label} at size ${fontSize.round()}',
                style: previewStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    SettingsController controller,
  ) {
    final currentMode = controller.themeMode;
    final labelStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in _themeModes)
                ChoiceChip(
                  avatar: Icon(_themeModeIcon(mode), size: 18),
                  showCheckmark: false,
                  label: Text(
                    _themeModeLabel(mode),
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: labelStyle,
                  ),
                  selected: currentMode == mode,
                  onSelected: (selected) {
                    if (!selected) return;
                    controller.setThemeMode(mode);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _themeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.night:
        return Icons.bedtime_outlined;
      case AppThemeMode.sepia:
        return Icons.auto_stories_outlined;
    }
  }

  String _themeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.night:
        return 'Night';
      case AppThemeMode.sepia:
        return 'Sepia';
    }
  }

  Widget _buildAiSection(BuildContext context, SettingsController controller) {
    final defaultSelection = controller.defaultModelSelection;
    final fallbackSelection = controller.fallbackModelSelection;
    final imageSelection = controller.imageModelSelection;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _openRouterApiKeyController,
            obscureText: _obscureOpenRouterApiKey,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: controller.setOpenRouterApiKey,
            decoration: InputDecoration(
              labelText: 'OpenRouter API Key',
              hintText: 'sk-or-v1-...',
              border: const OutlineInputBorder(),
              helperText: 'Stored locally on this device.',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureOpenRouterApiKey = !_obscureOpenRouterApiKey;
                  });
                },
                icon: Icon(
                  _obscureOpenRouterApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscureOpenRouterApiKey ? 'Show key' : 'Hide key',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiApiKeyController,
            obscureText: _obscureGeminiApiKey,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onChanged: controller.setGeminiApiKey,
            decoration: InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'AIza...',
              border: const OutlineInputBorder(),
              helperText: 'Stored locally on this device.',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureGeminiApiKey = !_obscureGeminiApiKey;
                  });
                },
                icon: Icon(
                  _obscureGeminiApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscureGeminiApiKey ? 'Show key' : 'Hide key',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default Model'),
            subtitle: Text(
              _selectionSubtitle(
                defaultSelection,
                emptyLabel: 'No model selected',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.search),
            onTap: () => _showModelPicker(context, controller),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fallback Model'),
            subtitle: Text(
              _selectionSubtitle(
                fallbackSelection,
                emptyLabel: 'No fallback model selected',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.search),
            onTap: () => _showFallbackModelPicker(context, controller),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Image Model'),
            subtitle: Text(
              _selectionSubtitle(
                imageSelection,
                emptyLabel: 'No image model selected',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.image_search_outlined),
            onTap: () => _showImageModelPicker(context, controller),
          ),
          const SizedBox(height: 8),
          Text(
            'AI Features',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ...aiFeatures.map((feature) {
            final config = controller.aiFeatureConfig(feature.id);
            final usesGlobalModel = !config.modelOverride.isConfigured;
            final modelLabel = _featureModelLabel(
              usesGlobalModel ? defaultSelection : config.modelOverride,
              usesGlobalModel: usesGlobalModel,
            );
            final imageModelHint = feature.id == AiFeatureIds.generateImage
                ? '\nImage model: ${_selectionSubtitle(imageSelection, emptyLabel: 'Not set')}'
                : '';
            final promptPreview = config.promptTemplate
                .replaceAll('\n', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(feature.title),
              subtitle: Text(
                '$modelLabel$imageModelHint\nPrompt: $promptPreview',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.tune),
              onTap: () => _showFeatureConfigSheet(
                context,
                controller,
                feature,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AiProviderModelPickerSheet extends StatefulWidget {
  final Future<List<AiModelInfo>> Function({
    required AiProvider provider,
    bool forceRefresh,
  }) loadModels;
  final String Function(AiProvider provider) apiKeyForProvider;
  final AiModelSelection selectedSelection;
  final String requiredOutputModality;
  final String title;
  final ValueChanged<AiModelSelection> onModelSelected;

  const _AiProviderModelPickerSheet({
    required this.loadModels,
    required this.apiKeyForProvider,
    required this.selectedSelection,
    required this.requiredOutputModality,
    required this.title,
    required this.onModelSelected,
  });

  @override
  State<_AiProviderModelPickerSheet> createState() =>
      _AiProviderModelPickerSheetState();
}

class _AiProviderModelPickerSheetState
    extends State<_AiProviderModelPickerSheet> {
  late AiProvider _selectedProvider;
  Future<List<AiModelInfo>>? _modelsFuture;
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.selectedSelection.provider ?? _defaultProvider();
    _reloadModels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  AiProvider _defaultProvider() {
    if (widget.apiKeyForProvider(AiProvider.openRouter).trim().isNotEmpty) {
      return AiProvider.openRouter;
    }
    if (widget.apiKeyForProvider(AiProvider.gemini).trim().isNotEmpty) {
      return AiProvider.gemini;
    }
    return AiProvider.openRouter;
  }

  void _reloadModels({bool forceRefresh = false}) {
    final apiKey = widget.apiKeyForProvider(_selectedProvider).trim();
    setState(() {
      _modelsFuture = apiKey.isEmpty
          ? null
          : widget.loadModels(
              provider: _selectedProvider,
              forceRefresh: forceRefresh,
            );
    });
  }

  List<AiModelInfo> _filterModels(List<AiModelInfo> models) {
    final requiredOutputModality =
        widget.requiredOutputModality.trim().toLowerCase();
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredByOutput = models.where((model) {
      switch (requiredOutputModality) {
        case 'image':
          return model.supportsImageOutput;
        case 'text':
          return model.supportsTextOutput;
        default:
          return true;
      }
    }).toList(growable: false);

    final filteredByQuery = normalizedQuery.isEmpty
        ? filteredByOutput
        : filteredByOutput.where((model) {
            final description = model.description?.toLowerCase() ?? '';
            return model.id.toLowerCase().contains(normalizedQuery) ||
                model.displayName.toLowerCase().contains(normalizedQuery) ||
                description.contains(normalizedQuery);
          }).toList(growable: false);

    if (requiredOutputModality != 'image') {
      return filteredByQuery;
    }

    final filtered = List<AiModelInfo>.from(filteredByQuery);
    filtered.sort((a, b) {
      final byRelevance = _imageModelRelevance(a).compareTo(
        _imageModelRelevance(b),
      );
      if (byRelevance != 0) return byRelevance;

      final byName = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
      if (byName != 0) return byName;
      return a.id.toLowerCase().compareTo(b.id.toLowerCase());
    });
    return filtered;
  }

  int _imageModelRelevance(AiModelInfo model) {
    if (model.supportsImageOutput && model.supportsTextOutput) return 0;
    if (model.supportsImageOutput) return 1;
    return 2;
  }

  AiModelPriceDisplayMode get _priceDisplayMode {
    return widget.requiredOutputModality.trim().toLowerCase() == 'image'
        ? AiModelPriceDisplayMode.imagePreferred
        : AiModelPriceDisplayMode.textPreferred;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final apiKey = widget.apiKeyForProvider(_selectedProvider).trim();
    final selectedSelection = widget.selectedSelection;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<AiProvider>(
                segments: const [
                  ButtonSegment(
                    value: AiProvider.openRouter,
                    label: Text('OpenRouter'),
                  ),
                  ButtonSegment(
                    value: AiProvider.gemini,
                    label: Text('Gemini'),
                  ),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (selection) {
                  final provider = selection.first;
                  if (provider == _selectedProvider) return;
                  _selectedProvider = provider;
                  _reloadModels();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by model name or id',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: apiKey.isEmpty
                  ? _MissingApiKeyMessage(provider: _selectedProvider)
                  : FutureBuilder<List<AiModelInfo>>(
                      future: _modelsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _ModelPickerError(
                            message: snapshot.error.toString(),
                            onRetry: () => _reloadModels(forceRefresh: true),
                          );
                        }

                        final models = snapshot.data ?? const <AiModelInfo>[];
                        final filtered = _filterModels(models);
                        final selectedInList = filtered.any(
                          (model) =>
                              model.id == selectedSelection.normalizedModelId &&
                              selectedSelection.provider == _selectedProvider,
                        );

                        return Column(
                          children: [
                            if (selectedSelection.isConfigured &&
                                selectedSelection.provider ==
                                    _selectedProvider &&
                                !selectedInList)
                              _SelectedModelWarning(
                                selection: selectedSelection,
                              ),
                            Expanded(
                              child: filtered.isEmpty
                                  ? _NoModelsFound(
                                      message: widget.requiredOutputModality
                                                  .trim()
                                                  .toLowerCase() ==
                                              'image'
                                          ? 'No image-generating models match your search.'
                                          : 'No text-capable models match your search.',
                                    )
                                  : MobileScrollbar(
                                      controller: _scrollController,
                                      child: ListView.separated(
                                        controller: _scrollController,
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final model = filtered[index];
                                          final isSelected =
                                              selectedSelection.provider ==
                                                      _selectedProvider &&
                                                  model.id ==
                                                      selectedSelection
                                                          .normalizedModelId;

                                          return ListTile(
                                            selected: isSelected,
                                            selectedTileColor: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withAlpha(80),
                                            title: Text(model.displayName),
                                            subtitle: _ModelSubtitle(
                                              model: model,
                                              priceDisplayMode:
                                                  _priceDisplayMode,
                                            ),
                                            trailing: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  )
                                                : null,
                                            onTap: () => widget.onModelSelected(
                                              AiModelSelection(
                                                provider: _selectedProvider,
                                                modelId: model.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSubtitle extends StatelessWidget {
  final AiModelInfo model;
  final AiModelPriceDisplayMode priceDisplayMode;

  const _ModelSubtitle({
    required this.model,
    required this.priceDisplayMode,
  });

  @override
  Widget build(BuildContext context) {
    final contextLabel =
        model.contextLength != null ? 'Context: ${model.contextLength}' : null;
    final outputsLabel = model.outputModalities.isEmpty
        ? null
        : 'Outputs: ${model.outputModalities.join(', ')}';
    final metadata = <String>[
      if (contextLabel != null) contextLabel,
      if (outputsLabel != null) outputsLabel,
    ];
    final idText =
        metadata.isEmpty ? model.id : '${model.id} · ${metadata.join(' · ')}';
    final priceText = model.settingsPriceLabel(priceDisplayMode);
    final description = model.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          idText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (priceText != null)
          Text(
            priceText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        if (description != null)
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
      ],
    );
  }
}

class _SelectedModelWarning extends StatelessWidget {
  final AiModelSelection selection;

  const _SelectedModelWarning({
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final providerLabel = selection.provider?.label ?? 'Unknown';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Saved model: $providerLabel · ${selection.normalizedModelId} (not in current list).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _MissingApiKeyMessage extends StatelessWidget {
  final AiProvider provider;

  const _MissingApiKeyMessage({
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your ${provider.label} API key first.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoModelsFound extends StatelessWidget {
  final String message;

  const _NoModelsFound({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelPickerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ModelPickerError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load models',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
