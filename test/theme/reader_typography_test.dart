import 'package:scroll/models/reader_settings.dart';
import 'package:scroll/theme/reader_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('buildReaderContentTextStyle', () {
    testWidgets(
      'applies the selected reader font family and full reader sizing',
      (tester) async {
        late TextStyle style;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                style = buildReaderContentTextStyle(
                  context: context,
                  fontSize: 24,
                  fontFamily: ReaderFontFamily.bitter,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(style.fontFamily, GoogleFonts.bitter().fontFamily);
        expect(style.fontSize, 24);
        expect(style.height, readerContentLineHeight);
      },
    );

    testWidgets(
      'preserves the theme body font for the system reader font option',
      (tester) async {
        late TextStyle style;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontFamily: 'ThemeBody'),
              ),
            ),
            home: Builder(
              builder: (context) {
                style = buildReaderContentTextStyle(
                  context: context,
                  fontSize: 20,
                  fontFamily: ReaderFontFamily.system,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(style.fontFamily, 'ThemeBody');
        expect(style.fontSize, 20);
        expect(style.height, readerContentLineHeight);
      },
    );
  });
}
