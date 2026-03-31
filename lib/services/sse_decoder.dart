import 'dart:convert';

class SseDataEvent {
  final String data;
  final String? event;
  final String? id;
  final int? retryMilliseconds;

  const SseDataEvent({
    required this.data,
    this.event,
    this.id,
    this.retryMilliseconds,
  });

  bool get isDone => data.trim() == '[DONE]';
}

class SseDecoder {
  final List<SseDataEvent> _queuedEvents = <SseDataEvent>[];
  final List<String> _dataLines = <String>[];

  late final ByteConversionSink _utf8Sink;

  String _pendingText = '';
  String? _eventType;
  String? _eventId;
  int? _retryMilliseconds;
  bool _isClosed = false;

  SseDecoder() {
    _utf8Sink =
        const Utf8Decoder().startChunkedConversion(_ChunkStringSink(_onText));
  }

  List<SseDataEvent> addChunk(List<int> bytes) {
    if (_isClosed) {
      throw StateError('SseDecoder is closed.');
    }
    if (bytes.isEmpty) {
      return const <SseDataEvent>[];
    }

    _utf8Sink.add(bytes);
    return _drainEvents();
  }

  List<SseDataEvent> close({bool emitIncompleteEvent = false}) {
    if (_isClosed) {
      return const <SseDataEvent>[];
    }
    _isClosed = true;
    _utf8Sink.close();

    if (_pendingText.isNotEmpty) {
      _processLine(_pendingText);
      _pendingText = '';
    }

    if (emitIncompleteEvent) {
      _emitEventIfPresent();
    } else {
      _resetEventFields();
    }

    return _drainEvents();
  }

  void _onText(String value) {
    if (value.isEmpty) return;

    _pendingText += value;
    _parsePendingText();
  }

  void _parsePendingText() {
    var start = 0;
    var index = 0;

    while (index < _pendingText.length) {
      final codeUnit = _pendingText.codeUnitAt(index);

      if (codeUnit == 0x0D) {
        if (index + 1 >= _pendingText.length) {
          break;
        }

        _processLine(_pendingText.substring(start, index));
        if (_pendingText.codeUnitAt(index + 1) == 0x0A) {
          index += 2;
        } else {
          index += 1;
        }
        start = index;
        continue;
      }

      if (codeUnit == 0x0A) {
        _processLine(_pendingText.substring(start, index));
        index += 1;
        start = index;
        continue;
      }

      index += 1;
    }

    if (start > 0) {
      _pendingText = _pendingText.substring(start);
    }
  }

  void _processLine(String line) {
    if (line.isEmpty) {
      _emitEventIfPresent();
      return;
    }

    if (line.startsWith(':')) {
      return;
    }

    final separatorIndex = line.indexOf(':');
    final fieldName =
        separatorIndex == -1 ? line : line.substring(0, separatorIndex);
    var fieldValue =
        separatorIndex == -1 ? '' : line.substring(separatorIndex + 1);
    if (fieldValue.startsWith(' ')) {
      fieldValue = fieldValue.substring(1);
    }

    switch (fieldName) {
      case 'data':
        _dataLines.add(fieldValue);
        return;
      case 'event':
        _eventType = fieldValue;
        return;
      case 'id':
        if (!fieldValue.contains('\u0000')) {
          _eventId = fieldValue;
        }
        return;
      case 'retry':
        final value = int.tryParse(fieldValue);
        if (value != null) {
          _retryMilliseconds = value;
        }
        return;
      default:
        return;
    }
  }

  void _emitEventIfPresent() {
    if (_dataLines.isEmpty) {
      _eventType = null;
      _eventId = null;
      _retryMilliseconds = null;
      return;
    }

    _queuedEvents.add(
      SseDataEvent(
        data: _dataLines.join('\n'),
        event: _eventType,
        id: _eventId,
        retryMilliseconds: _retryMilliseconds,
      ),
    );

    _resetEventFields();
  }

  void _resetEventFields() {
    _dataLines.clear();
    _eventType = null;
    _eventId = null;
    _retryMilliseconds = null;
  }

  List<SseDataEvent> _drainEvents() {
    if (_queuedEvents.isEmpty) {
      return const <SseDataEvent>[];
    }

    final events = List<SseDataEvent>.unmodifiable(_queuedEvents);
    _queuedEvents.clear();
    return events;
  }
}

class _ChunkStringSink implements Sink<String> {
  final void Function(String value) _onData;

  const _ChunkStringSink(this._onData);

  @override
  void add(String data) {
    _onData(data);
  }

  @override
  void close() {}
}
