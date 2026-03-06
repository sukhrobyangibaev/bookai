import 'package:bookai/widgets/reader_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildReaderSelectionButtonItems', () {
    test('keeps copy, drops select all, and appends reader actions', () {
      final items = buildReaderSelectionButtonItems(
        platformItems: [
          ContextMenuButtonItem(
            type: ContextMenuButtonType.copy,
            label: 'Copy',
            onPressed: () {},
          ),
          ContextMenuButtonItem(
            type: ContextMenuButtonType.selectAll,
            label: 'Select All',
            onPressed: () {},
          ),
        ],
        onCopy: () {},
        onHighlight: () {},
        onDefineAndTranslate: () {},
        onResumeHere: () {},
        onCatchMeUp: () {},
      );

      expect(items, hasLength(5));
      expect(items.first.type, ContextMenuButtonType.copy);
      expect(
        items.where((item) => item.type == ContextMenuButtonType.selectAll),
        isEmpty,
      );
      expect(items.map((item) => item.label).toList(), [
        'Copy',
        'Highlight',
        'Define & Translate',
        'Resume Here',
        'Catch Me Up',
      ]);
    });
  });

  group('ReaderSelectionToolbar', () {
    testWidgets('shows all reader actions inline without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(200, 200),
                secondaryAnchor: Offset(200, 240),
              ),
              buttonItems: buildReaderSelectionButtonItems(
                platformItems: [
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    label: 'Copy',
                    onPressed: () {},
                  ),
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.selectAll,
                    label: 'Select All',
                    onPressed: () {},
                  ),
                ],
                onCopy: () {},
                onHighlight: () {},
                onDefineAndTranslate: () {},
                onResumeHere: () {},
                onCatchMeUp: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Highlight'), findsOneWidget);
      expect(find.text('Define & Translate'), findsOneWidget);
      expect(find.text('Resume Here'), findsOneWidget);
      expect(find.text('Catch Me Up'), findsOneWidget);
      expect(find.text('Select All'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('invokes reader action callbacks', (tester) async {
      var definePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(200, 200),
                secondaryAnchor: Offset(200, 240),
              ),
              buttonItems: buildReaderSelectionButtonItems(
                platformItems: [
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    label: 'Copy',
                    onPressed: () {},
                  ),
                ],
                onCopy: () {},
                onHighlight: () {},
                onDefineAndTranslate: () {
                  definePressed = true;
                },
                onResumeHere: () {
                  fail('Resume Here should not be tapped in this test.');
                },
                onCatchMeUp: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Define & Translate'));
      await tester.pump();

      expect(definePressed, isTrue);
    });
  });
}
