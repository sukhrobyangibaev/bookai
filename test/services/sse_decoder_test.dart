import 'dart:convert';

import 'package:bookai/services/sse_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SseDecoder', () {
    test('emits an event only after a blank-line boundary', () {
      final decoder = SseDecoder();

      final beforeBoundary = decoder.addChunk(utf8.encode('data: Hel'));
      expect(beforeBoundary, isEmpty);

      final afterBoundary = decoder.addChunk(utf8.encode('lo\n\n'));
      expect(afterBoundary, hasLength(1));
      expect(afterBoundary.single.data, 'Hello');
      expect(afterBoundary.single.event, isNull);
      expect(afterBoundary.single.id, isNull);
      expect(afterBoundary.single.retryMilliseconds, isNull);
      expect(afterBoundary.single.isDone, isFalse);
    });

    test('parses multiple events in one chunk', () {
      final decoder = SseDecoder();

      final events = decoder.addChunk(
        utf8.encode(
          'data: first\n\n'
          'id: 7\n'
          'event: message\n'
          'data: second line 1\n'
          'data: second line 2\n\n',
        ),
      );

      expect(events, hasLength(2));
      expect(events[0].data, 'first');
      expect(events[0].event, isNull);
      expect(events[0].id, isNull);

      expect(events[1].data, 'second line 1\nsecond line 2');
      expect(events[1].event, 'message');
      expect(events[1].id, '7');
    });

    test('ignores comment lines and does not emit metadata-only events', () {
      final decoder = SseDecoder();

      final metadataOnly = decoder.addChunk(
        utf8.encode(': ping\nid: 1\n\n'),
      );
      expect(metadataOnly, isEmpty);

      final withComment = decoder.addChunk(
        utf8.encode('event: update\n: ignore\ndata: payload\n\n'),
      );
      expect(withComment, hasLength(1));
      expect(withComment.single.data, 'payload');
      expect(withComment.single.event, 'update');
      expect(withComment.single.id, isNull);
    });

    test('exposes done marker and retry metadata', () {
      final decoder = SseDecoder();

      final events = decoder.addChunk(
        utf8.encode('retry: 1500\ndata: [DONE]\n\n'),
      );

      expect(events, hasLength(1));
      expect(events.single.data, '[DONE]');
      expect(events.single.retryMilliseconds, 1500);
      expect(events.single.isDone, isTrue);
    });

    test('supports CRLF boundaries split across chunks', () {
      final decoder = SseDecoder();

      final first = decoder.addChunk(utf8.encode('data: one\r'));
      expect(first, isEmpty);

      final second = decoder.addChunk(utf8.encode('\n\r\n'));
      expect(second, hasLength(1));
      expect(second.single.data, 'one');
    });

    test('close can emit a final incomplete event when requested', () {
      final decoder = SseDecoder();

      decoder.addChunk(utf8.encode('data: trailing'));

      final withoutEmit = decoder.close();
      expect(withoutEmit, isEmpty);
    });

    test('close emits an incomplete event when enabled', () {
      final decoder = SseDecoder();

      decoder.addChunk(utf8.encode('data: trailing'));

      final events = decoder.close(emitIncompleteEvent: true);
      expect(events, hasLength(1));
      expect(events.single.data, 'trailing');
    });

    test('throws when adding chunks after close', () {
      final decoder = SseDecoder();
      decoder.close();

      expect(
        () => decoder.addChunk(utf8.encode('data: test\n\n')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
