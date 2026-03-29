import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/ai_request_log_entry.dart';
import '../services/database_service.dart';
import '../widgets/mobile_scrollbar.dart';

class AiLogsScreen extends StatefulWidget {
  final DatabaseService? databaseService;
  final Future<int> Function()? countLogs;
  final Future<List<AiRequestLogEntry>> Function({
    required int limit,
    required int offset,
  })? loadLogs;
  final Future<int> Function()? clearLogs;

  const AiLogsScreen({
    super.key,
    this.databaseService,
    this.countLogs,
    this.loadLogs,
    this.clearLogs,
  });

  @override
  State<AiLogsScreen> createState() => _AiLogsScreenState();
}

class _AiLogsScreenState extends State<AiLogsScreen> {
  static const int _pageSize = 25;

  late final DatabaseService _databaseService;
  final ScrollController _scrollController = ScrollController();
  final List<AiRequestLogEntry> _entries = <AiRequestLogEntry>[];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _databaseService = widget.databaseService ?? DatabaseService.instance;
    _loadInitial();
  }

  Future<int> _countLogs() {
    final override = widget.countLogs;
    if (override != null) return override();
    return _databaseService.countAiRequestLogEntries();
  }

  Future<List<AiRequestLogEntry>> _loadLogsPage({
    required int limit,
    required int offset,
  }) {
    final override = widget.loadLogs;
    if (override != null) {
      return override(limit: limit, offset: offset);
    }
    return _databaseService.getAiRequestLogEntries(
        limit: limit, offset: offset);
  }

  Future<int> _clearLogsFromStorage() {
    final override = widget.clearLogs;
    if (override != null) return override();
    return _databaseService.clearAiRequestLogEntries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _isLoadingMore = false;
      _hasMore = true;
      _loadError = null;
      _entries.clear();
      _totalCount = 0;
    });

    try {
      final totalCount = await _countLogs();
      final page = await _loadLogsPage(
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _totalCount = totalCount;
        _hasMore = _entries.length < totalCount;
        _isLoadingInitial = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingInitial = false;
        _loadError = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingInitial || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _loadLogsPage(
        limit: _pageSize,
        offset: _entries.length,
      );
      if (!mounted) return;

      setState(() {
        _entries.addAll(page);
        _hasMore = page.isNotEmpty && _entries.length < _totalCount;
        if (page.isEmpty) {
          _totalCount = _entries.length;
        }
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadError = error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more logs: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear AI Logs'),
        content: const Text(
          'Delete all saved AI request logs from this device?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final removed = await _clearLogsFromStorage();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed == 1
              ? 'Cleared 1 log entry.'
              : 'Cleared $removed log entries.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _loadInitial();
  }

  Future<void> _openLogDetail(AiRequestLogEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _AiLogDetailSheet(entry: entry),
        );
      },
    );
  }

  String _subtitleForEntry(AiRequestLogEntry entry) {
    final status = entry.responseStatusCode?.toString() ?? 'ERR';
    final model = entry.modelId == null || entry.modelId!.trim().isEmpty
        ? ''
        : ' · ${entry.modelId}';
    final durationLabel =
        entry.durationMs == null ? '' : ' · ${entry.durationMs}ms';
    return '${entry.provider.toUpperCase()} · ${entry.requestKind} · $status$model$durationLabel';
  }

  String _titleForEntry(AiRequestLogEntry entry) {
    final method = entry.method.toUpperCase();
    final uri = Uri.tryParse(entry.url);
    final path = uri?.path ?? entry.url;
    return '$method $path';
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load AI logs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No AI logs yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Run any AI action and the request/response records will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: MobileScrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _entries.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == _entries.length) {
              if (_isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_hasMore) {
                return Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Load more (${_entries.length}/$_totalCount)',
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'Showing all ${_entries.length} log entries',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }

            final entry = _entries[index];
            final hasError = entry.errorMessage != null;
            final statusColor = hasError
                ? Theme.of(context).colorScheme.error
                : (entry.responseStatusCode != null &&
                        entry.responseStatusCode! >= 400)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary;

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                onTap: () => _openLogDetail(entry),
                title: Text(
                  _titleForEntry(entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForEntry(entry),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(entry.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (entry.responseMetadataOnly)
                      Text(
                        'Image response stored as metadata only',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: statusColor.withAlpha(35),
                  child: Icon(
                    hasError ? Icons.error_outline : Icons.swap_horiz,
                    size: 16,
                    color: statusColor,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Logs'),
        actions: [
          IconButton(
            onPressed: _isLoadingInitial ? null : _loadInitial,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _entries.isEmpty ? null : _clearLogs,
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

class _AiLogDetailSheet extends StatelessWidget {
  final AiRequestLogEntry entry;

  const _AiLogDetailSheet({required this.entry});

  String _prettyJsonIfPossible(String? text) {
    if (text == null || text.trim().isEmpty) return '(empty)';
    final trimmed = text.trim();
    try {
      final decoded = jsonDecode(trimmed);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return text;
    }
  }

  String _headersForDisplay(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '(none)';
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            body,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final responseStatus = entry.responseStatusCode?.toString() ?? '(none)';
    final requestBody = _prettyJsonIfPossible(entry.requestBody);
    final responseBody = _prettyJsonIfPossible(entry.responseBody);
    final requestHeaders = _headersForDisplay(entry.requestHeaders);
    final responseHeaders = _headersForDisplay(entry.responseHeaders);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log #${entry.id ?? '-'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.provider.toUpperCase()} · ${entry.requestKind} · ${entry.method} ${entry.url}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Attempt ${entry.attempt} · Status $responseStatus'
              '${entry.durationMs == null ? '' : ' · ${entry.durationMs}ms'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (entry.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${entry.errorMessage}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            if (entry.responseMetadataOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Image response stored as metadata only.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: MobileScrollbar(
                child: ListView(
                  children: [
                    _section(
                      context,
                      title: 'Request Headers',
                      body: requestHeaders,
                    ),
                    const SizedBox(height: 12),
                    _section(
                      context,
                      title: 'Request Body',
                      body: requestBody,
                    ),
                    const SizedBox(height: 12),
                    _section(
                      context,
                      title: 'Response Headers',
                      body: responseHeaders,
                    ),
                    const SizedBox(height: 12),
                    _section(
                      context,
                      title: 'Response Body',
                      body: responseBody,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final year = local.year;
  final month = twoDigits(local.month);
  final day = twoDigits(local.day);
  final hour = twoDigits(local.hour);
  final minute = twoDigits(local.minute);
  final second = twoDigits(local.second);
  return '$year-$month-$day $hour:$minute:$second';
}
