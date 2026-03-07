import 'package:bookai/app.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/screens/settings_screen.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('SettingsScreen', () {
    testWidgets('shows reader font options', (tester) async {
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

      expect(find.text('Font'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Literata'), findsOneWidget);
      expect(find.text('Bitter'), findsOneWidget);
      expect(find.text('Atkinson Hyperlegible'), findsOneWidget);
    });

    testWidgets('selecting font updates controller value', (tester) async {
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

      await tester.tap(find.text('Bitter'));
      await tester.pumpAndSettle();

      expect(controller.fontFamily, ReaderFontFamily.bitter);
    });

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
      expect(find.text('Resume Here and Catch Me Up'), findsOneWidget);
      expect(find.text('Simplify Text'), findsOneWidget);
      expect(find.text('Define & Translate'), findsOneWidget);
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

    testWidgets('shows context sentence placeholder for define and translate',
        (tester) async {
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

      final defineAndTranslateTile = find.widgetWithText(
        ListTile,
        'Define & Translate',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(defineAndTranslateTile);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Supported placeholders: {book_title}, {book_author}, {context_sentence}, {source_text}',
        ),
        findsOneWidget,
      );
    });
  });
}
