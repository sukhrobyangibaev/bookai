import 'package:flutter/material.dart';

import '../app.dart';
import '../models/openrouter_model.dart';
import '../models/reader_settings.dart';
import '../services/openrouter_service.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  final OpenRouterService _openRouterService = OpenRouterService();
  bool _obscureApiKey = true;
  SettingsController? _controllerForSync;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = SettingsControllerScope.of(context);
    if (_controllerForSync != controller) {
      _controllerForSync?.removeListener(_syncApiKeyField);
      _controllerForSync = controller;
      _controllerForSync!.addListener(_syncApiKeyField);
      _syncApiKeyField();
    }
  }

  @override
  void dispose() {
    _controllerForSync?.removeListener(_syncApiKeyField);
    _apiKeyController.dispose();
    super.dispose();
  }

  void _syncApiKeyField() {
    final controller = _controllerForSync;
    if (controller == null) return;

    final apiKey = controller.openRouterApiKey;
    if (_apiKeyController.text == apiKey) return;

    _apiKeyController.value = _apiKeyController.value.copyWith(
      text: apiKey,
      selection: TextSelection.collapsed(offset: apiKey.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _showModelPicker(
    BuildContext context,
    SettingsController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _OpenRouterModelPickerSheet(
            service: _openRouterService,
            apiKey: controller.openRouterApiKey,
            selectedModelId: controller.openRouterModelId,
            onModelSelected: (modelId) {
              controller.setOpenRouterModelId(modelId);
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _buildFontSizeSection(context, controller),
              const Divider(height: 32),
              _buildThemeSection(context, controller),
              const Divider(height: 32),
              _buildAiSection(context, controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFontSizeSection(
      BuildContext context, SettingsController controller) {
    final fontSize = controller.fontSize;

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
                'Preview text at size ${fontSize.round()}',
                style: TextStyle(fontSize: fontSize, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(
      BuildContext context, SettingsController controller) {
    final currentMode = controller.themeMode;

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
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment(
                value: AppThemeMode.sepia,
                label: Text('Sepia'),
                icon: Icon(Icons.auto_stories_outlined),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selected) {
              controller.setThemeMode(selected.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context, SettingsController controller) {
    final selectedModelId = controller.openRouterModelId;
    final selectedModelLabel =
        selectedModelId.isEmpty ? 'No model selected' : selectedModelId;

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
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
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
                    _obscureApiKey = !_obscureApiKey;
                  });
                },
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscureApiKey ? 'Show key' : 'Hide key',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Model'),
            subtitle: Text(
              selectedModelLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.search),
            onTap: () => _showModelPicker(context, controller),
          ),
        ],
      ),
    );
  }
}

class _OpenRouterModelPickerSheet extends StatefulWidget {
  final OpenRouterService service;
  final String apiKey;
  final String selectedModelId;
  final ValueChanged<String> onModelSelected;

  const _OpenRouterModelPickerSheet({
    required this.service,
    required this.apiKey,
    required this.selectedModelId,
    required this.onModelSelected,
  });

  @override
  State<_OpenRouterModelPickerSheet> createState() =>
      _OpenRouterModelPickerSheetState();
}

class _OpenRouterModelPickerSheetState
    extends State<_OpenRouterModelPickerSheet> {
  late Future<List<OpenRouterModel>> _modelsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _modelsFuture = _loadModels();
  }

  Future<List<OpenRouterModel>> _loadModels({bool forceRefresh = false}) {
    return widget.service.fetchModels(
      apiKey: widget.apiKey,
      forceRefresh: forceRefresh,
    );
  }

  void _retry() {
    setState(() {
      _modelsFuture = _loadModels(forceRefresh: true);
    });
  }

  List<OpenRouterModel> _filterModels(List<OpenRouterModel> models) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return models;

    return models.where((model) {
      final description = model.description?.toLowerCase() ?? '';
      return model.id.toLowerCase().contains(normalizedQuery) ||
          model.displayName.toLowerCase().contains(normalizedQuery) ||
          description.contains(normalizedQuery);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                    'Choose OpenRouter Model',
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
              child: FutureBuilder<List<OpenRouterModel>>(
                future: _modelsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ModelPickerError(
                      message: snapshot.error.toString(),
                      onRetry: _retry,
                    );
                  }

                  final models = snapshot.data ?? const <OpenRouterModel>[];
                  final filtered = _filterModels(models);
                  final selectedModelId = widget.selectedModelId;
                  final selectedInList = models.any(
                    (model) => model.id == selectedModelId,
                  );

                  return Column(
                    children: [
                      if (selectedModelId.isNotEmpty && !selectedInList)
                        _SelectedModelWarning(modelId: selectedModelId),
                      Expanded(
                        child: filtered.isEmpty
                            ? const _NoModelsFound()
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final model = filtered[index];
                                  final isSelected =
                                      model.id == selectedModelId;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withAlpha(80),
                                    title: Text(model.displayName),
                                    subtitle: _ModelSubtitle(model: model),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          )
                                        : null,
                                    onTap: () =>
                                        widget.onModelSelected(model.id),
                                  );
                                },
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
  final OpenRouterModel model;

  const _ModelSubtitle({required this.model});

  @override
  Widget build(BuildContext context) {
    final contextLabel =
        model.contextLength != null ? 'Context: ${model.contextLength}' : null;

    final idText =
        contextLabel == null ? model.id : '${model.id} · $contextLabel';
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
  final String modelId;

  const _SelectedModelWarning({required this.modelId});

  @override
  Widget build(BuildContext context) {
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
          'Saved model: $modelId (not in current list).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _NoModelsFound extends StatelessWidget {
  const _NoModelsFound();

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
              'No models match your search.',
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
