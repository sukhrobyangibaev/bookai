import 'package:bookai/app.dart';
import 'package:bookai/screens/settings_screen.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen AI section', () {
    testWidgets('shows persisted OpenRouter model id', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'stored-key',
        'reader_openrouter_model_id': 'openai/gpt-4o-mini',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        SettingsControllerScope(
          controller: controller,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('OpenRouter API Key'), findsOneWidget);
      expect(find.text('openai/gpt-4o-mini'), findsOneWidget);
    });

    testWidgets('editing API key updates controller value', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        SettingsControllerScope(
          controller: controller,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '  test-key  ');
      await tester.pump();

      expect(controller.openRouterApiKey, 'test-key');
    });
  });
}
