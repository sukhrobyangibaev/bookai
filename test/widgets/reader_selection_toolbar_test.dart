import 'package:scroll/widgets/reader_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoundedRectangleBorder toolbarShapeFor(WidgetTester tester, String keyValue) {
    final material = tester.widget<Material>(
      find.byKey(ValueKey<String>(keyValue)),
    );
    return material.shape! as RoundedRectangleBorder;
  }

  Offset buttonCenterFor(WidgetTester tester, String keyValue) {
    return tester.getCenter(find.byKey(ValueKey<String>(keyValue)));
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
        onGenerateImage: () {},
        onSimplifyText: () {},
        onAskAi: () {},
        onResumeHere: () {},
        onCatchMeUp: () {},
      );

      expect(items, hasLength(8));
      expect(items.first.type, ContextMenuButtonType.copy);
      expect(
        items.where((item) => item.type == ContextMenuButtonType.selectAll),
        isEmpty,
      );
      expect(items.map((item) => item.label).toList(), [
        'Copy',
        'Highlight',
        'Define & Translate',
        'Generate Image',
        'Simplify Text',
        'Ask AI',
        'Catch Me Up',
        'Resume Here',
      ]);
    });
  });

  group('ReaderSelectionToolbar', () {
    testWidgets('shows reader actions in fixed rows without overflow',
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
                onGenerateImage: () {},
                onSimplifyText: () {},
                onAskAi: () {},
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
      expect(find.text('Generate Image'), findsOneWidget);
      expect(find.text('Simplify Text'), findsOneWidget);
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Resume Here'), findsOneWidget);
      expect(find.text('Catch Me Up'), findsOneWidget);
      expect(find.text('Select All'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      final copyCenter = buttonCenterFor(
        tester,
        'reader-selection-button-copy',
      );
      final highlightCenter = buttonCenterFor(
        tester,
        'reader-selection-button-highlight',
      );
      final defineCenter = buttonCenterFor(
        tester,
        'reader-selection-button-define_and_translate',
      );
      final generateImageCenter = buttonCenterFor(
        tester,
        'reader-selection-button-generate_image',
      );
      final simplifyCenter = buttonCenterFor(
        tester,
        'reader-selection-button-simplify_text',
      );
      final askAiCenter = buttonCenterFor(
        tester,
        'reader-selection-button-ask_ai',
      );
      final catchMeUpCenter = buttonCenterFor(
        tester,
        'reader-selection-button-catch_me_up',
      );
      final resumeCenter = buttonCenterFor(
        tester,
        'reader-selection-button-resume_here',
      );

      expect(copyCenter.dy, moreOrLessEquals(highlightCenter.dy));
      expect(defineCenter.dy, moreOrLessEquals(generateImageCenter.dy));
      expect(simplifyCenter.dy, moreOrLessEquals(askAiCenter.dy));
      expect(simplifyCenter.dy, moreOrLessEquals(catchMeUpCenter.dy));
      expect(defineCenter.dy, greaterThan(copyCenter.dy));
      expect(simplifyCenter.dy, greaterThan(defineCenter.dy));
      expect(resumeCenter.dy, greaterThan(simplifyCenter.dy));

      expect(copyCenter.dx, lessThan(highlightCenter.dx));
      expect(defineCenter.dx, lessThan(generateImageCenter.dx));
      expect(simplifyCenter.dx, lessThan(askAiCenter.dx));
      expect(askAiCenter.dx, lessThan(catchMeUpCenter.dx));

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
                onGenerateImage: () {},
                onSimplifyText: () {
                  simplifyPressed = true;
                },
                onAskAi: () {},
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
                onGenerateImage: () {},
                onSimplifyText: () {},
                onAskAi: () {},
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
      final generateImageShape = toolbarShapeFor(
        tester,
        'reader-selection-button-generate_image',
      );
      final simplifyShape = toolbarShapeFor(
        tester,
        'reader-selection-button-simplify_text',
      );
      final askAiShape = toolbarShapeFor(
        tester,
        'reader-selection-button-ask_ai',
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
      expect(
          generateImageShape.side.color, isNot(equals(copyShape.side.color)));
      expect(simplifyShape.side.color, isNot(equals(copyShape.side.color)));
      expect(askAiShape.side.color, isNot(equals(copyShape.side.color)));
      expect(catchMeUpShape.side.color, isNot(equals(copyShape.side.color)));
      expect(defineShape.side.color, isNot(equals(simplifyShape.side.color)));
      expect(
        generateImageShape.side.color,
        isNot(equals(defineShape.side.color)),
      );
      expect(catchMeUpShape.side.color, isNot(equals(defineShape.side.color)));
      expect(askAiShape.side.color, isNot(equals(defineShape.side.color)));
      expect(
          catchMeUpShape.side.color, isNot(equals(simplifyShape.side.color)));
    });
  });
}
