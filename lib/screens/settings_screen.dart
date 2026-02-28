import 'package:flutter/material.dart';

import '../app.dart';
import '../models/reader_settings.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
}
