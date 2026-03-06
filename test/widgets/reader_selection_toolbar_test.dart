import 'package:bookai/widgets/reader_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoundedRectangleBorder toolbarShapeFor(WidgetTester tester, String keyValue) {
    final material = tester.widget<Material>(
      find.byKey(ValueKey<String>(keyValue)),
    );
    return material.shape! as RoundedRectangleBorder;
  }

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
        onSimplifyText: () {},
        onResumeHere: () {},
        onCatchMeUp: () {},
      );

      expect(items, hasLength(6));
      expect(items.first.type, ContextMenuButtonType.copy);
      expect(
        items.where((item) => item.type == ContextMenuButtonType.selectAll),
        isEmpty,
      );
      expect(items.map((item) => item.label).toList(), [
        'Copy',
        'Highlight',
        'Define & Translate',
        'Simplify Text',
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
                onSimplifyText: () {},
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
      expect(find.text('Simplify Text'), findsOneWidget);
      expect(find.text('Resume Here'), findsOneWidget);
      expect(find.text('Catch Me Up'), findsOneWidget);
      expect(find.text('Select All'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      final toolbarShape = toolbarShapeFor(
        tester,
        'reader-selection-toolbar-container',
      );
      expect(toolbarShape.side.color.alpha, greaterThan(0));
      expect(toolbarShape.side.width, greaterThan(0));
    });

    testWidgets('invokes reader action callbacks', (tester) async {
      var simplifyPressed = false;

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
                onDefineAndTranslate: () {},
                onSimplifyText: () {
                  simplifyPressed = true;
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

      await tester.tap(find.text('Simplify Text'));
      await tester.pump();

      expect(simplifyPressed, isTrue);
    });

    testWidgets('uses distinct accents only for AI actions', (tester) async {
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
                onDefineAndTranslate: () {},
                onSimplifyText: () {},
                onResumeHere: () {},
                onCatchMeUp: () {},
              ),
            ),
          ),
        ),
      );

      final copyShape = toolbarShapeFor(
        tester,
        'reader-selection-button-copy',
      );
      final highlightShape = toolbarShapeFor(
        tester,
        'reader-selection-button-highlight',
      );
      final defineShape = toolbarShapeFor(
        tester,
        'reader-selection-button-define_and_translate',
      );
      final simplifyShape = toolbarShapeFor(
        tester,
        'reader-selection-button-simplify_text',
      );
      final catchMeUpShape = toolbarShapeFor(
        tester,
        'reader-selection-button-catch_me_up',
      );
      final resumeShape = toolbarShapeFor(
        tester,
        'reader-selection-button-resume_here',
      );

      expect(copyShape.side.color, equals(highlightShape.side.color));
      expect(copyShape.side.color, equals(resumeShape.side.color));
      expect(defineShape.side.color, isNot(equals(copyShape.side.color)));
      expect(simplifyShape.side.color, isNot(equals(copyShape.side.color)));
      expect(catchMeUpShape.side.color, isNot(equals(copyShape.side.color)));
      expect(defineShape.side.color, isNot(equals(simplifyShape.side.color)));
      expect(catchMeUpShape.side.color, isNot(equals(defineShape.side.color)));
      expect(
          catchMeUpShape.side.color, isNot(equals(simplifyShape.side.color)));
    });
  });
}
