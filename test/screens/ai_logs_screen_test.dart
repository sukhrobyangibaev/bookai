import 'package:bookai/models/ai_request_log_entry.dart';
import 'package:bookai/screens/ai_logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state when no logs exist', (tester) async {
    await _pumpScreen(
      tester,
      countLogs: () async => 0,
      loadLogs: ({required int limit, required int offset}) async =>
          const <AiRequestLogEntry>[],
      clearLogs: () async => 0,
    );

    expect(find.text('AI Logs'), findsOneWidget);
    expect(find.text('No AI logs yet'), findsOneWidget);
  });

  testWidgets('paginates with load more button', (tester) async {
    final logs = List<AiRequestLogEntry>.generate(30, (index) {
      return AiRequestLogEntry(
        id: index + 1,
        createdAt: DateTime.utc(2026, 3, 29, 15, 0, index),
        provider: index.isEven ? 'openrouter' : 'gemini',
        requestKind: 'chat_generation',
        attempt: 1,
        method: 'POST',
        url: 'https://example.com/v1/test/$index',
        modelId: 'model-$index',
        requestHeaders: const {'Authorization': '<redacted>'},
        requestBody: '{"index":$index}',
        responseStatusCode: 200,
        responseHeaders: const {'content-type': 'application/json'},
        responseBody: '{"ok":true}',
        durationMs: 100 + index,
      );
    }).reversed.toList(growable: false);

    await _pumpScreen(
      tester,
      countLogs: () async => logs.length,
      loadLogs: ({required int limit, required int offset}) async {
        final end = (offset + limit).clamp(0, logs.length);
        return logs.sublist(offset, end);
      },
      clearLogs: () async => logs.length,
    );

    final loadMoreFinder = find.text('Load more (25/30)');
    await tester.scrollUntilVisible(
      loadMoreFinder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(loadMoreFinder, findsOneWidget);

    await tester.tap(loadMoreFinder);
    await tester.pumpAndSettle();

    final allEntriesFinder = find.text('Showing all 30 log entries');
    await tester.scrollUntilVisible(
      allEntriesFinder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(allEntriesFinder, findsOneWidget);
  });

  testWidgets('opens detail sheet for a log entry', (tester) async {
    final entry = AiRequestLogEntry(
      id: 7,
      createdAt: DateTime.utc(2026, 3, 29, 15, 0, 0),
      provider: 'openrouter',
      requestKind: 'chat_generation',
      attempt: 1,
      method: 'POST',
      url: 'https://example.com/v1/test/0',
      modelId: 'model-0',
      requestHeaders: const {'Authorization': '<redacted>'},
      requestBody: '{"question":"hello"}',
      responseStatusCode: 200,
      responseHeaders: const {'content-type': 'application/json'},
      responseBody: '{"answer":"world"}',
      durationMs: 112,
    );

    await _pumpScreen(
      tester,
      countLogs: () async => 1,
      loadLogs: ({required int limit, required int offset}) async => offset == 0
          ? <AiRequestLogEntry>[entry]
          : const <AiRequestLogEntry>[],
      clearLogs: () async => 1,
    );

    await tester.tap(find.text('POST /v1/test/0'));
    await tester.pumpAndSettle();

    expect(find.text('Log #7'), findsOneWidget);
    expect(find.text('Request Headers'), findsOneWidget);
    expect(find.text('Response Body'), findsOneWidget);
  });

  testWidgets('clears logs from app bar action', (tester) async {
    var logCount = 3;
    final seedLogs = List<AiRequestLogEntry>.generate(3, (index) {
      return AiRequestLogEntry(
        id: index + 1,
        createdAt: DateTime.utc(2026, 3, 29, 15, 0, index),
        provider: 'gemini',
        requestKind: 'chat_generation',
        attempt: 1,
        method: 'POST',
        url: 'https://example.com/v1/test/$index',
        requestHeaders: const {'x-goog-api-key': '<redacted>'},
      );
    }).reversed.toList(growable: false);

    await _pumpScreen(
      tester,
      countLogs: () async => logCount,
      loadLogs: ({required int limit, required int offset}) async {
        if (logCount == 0 || offset > 0) return const <AiRequestLogEntry>[];
        return seedLogs.take(limit).toList(growable: false);
      },
      clearLogs: () async {
        final removed = logCount;
        logCount = 0;
        return removed;
      },
    );

    await tester.tap(find.byTooltip('Clear logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Logs'));
    await tester.pumpAndSettle();

    expect(find.text('No AI logs yet'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Future<int> Function() countLogs,
  required Future<List<AiRequestLogEntry>> Function({
    required int limit,
    required int offset,
  }) loadLogs,
  required Future<int> Function() clearLogs,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AiLogsScreen(
        countLogs: countLogs,
        loadLogs: loadLogs,
        clearLogs: clearLogs,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
