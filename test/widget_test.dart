import 'package:flutter_test/flutter_test.dart';

import 'package:bookai/app.dart';

void main() {
  testWidgets('App renders LibraryScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookAiApp());

    expect(find.text('BookAI Library'), findsOneWidget);
    expect(find.text('Library Screen'), findsOneWidget);
  });
}
