import 'dart:math' as math;

import 'package:flutter/material.dart';

List<ContextMenuButtonItem> buildReaderSelectionButtonItems({
  required List<ContextMenuButtonItem> platformItems,
  required VoidCallback onCopy,
  required VoidCallback onHighlight,
  required VoidCallback onDefineAndTranslate,
  VoidCallback? onGenerateImage,
  required VoidCallback onSimplifyText,
  required VoidCallback onAskAi,
  required VoidCallback onResumeHere,
  required VoidCallback onCatchMeUp,
}) {
  ContextMenuButtonItem? copyItem;
  for (final item in platformItems) {
    if (item.type == ContextMenuButtonType.copy) {
      copyItem = item;
      break;
    }
  }

  return [
    copyItem ??
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: onCopy,
        ),
    ContextMenuButtonItem(
      label: 'Highlight',
      onPressed: onHighlight,
    ),
    ContextMenuButtonItem(
      label: 'Define & Translate',
      onPressed: onDefineAndTranslate,
    ),
    ContextMenuButtonItem(
      label: 'Generate Image',
      onPressed: onGenerateImage,
    ),
    ContextMenuButtonItem(
      label: 'Simplify Text',
      onPressed: onSimplifyText,
    ),
    ContextMenuButtonItem(
      label: 'Ask AI',
      onPressed: onAskAi,
    ),
    ContextMenuButtonItem(
      label: 'Catch Me Up',
      onPressed: onCatchMeUp,
    ),
    ContextMenuButtonItem(
      label: 'Resume Here',
      onPressed: onResumeHere,
    ),
  ];
}

class ReaderSelectionToolbar extends StatelessWidget {
  const ReaderSelectionToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
  });

  static const double _kToolbarBorderRadius = 22.0;
  static const double _kToolbarContentDistance = 8.0;
  static const double _kScreenPadding = 8.0;
  static const List<List<String>> _kButtonRows = [
    [_ToolbarActionStyle._copyId, _ToolbarActionStyle._highlightId],
    [
      _ToolbarActionStyle._defineAndTranslateId,
      _ToolbarActionStyle._generateImageId,
    ],
    [
      _ToolbarActionStyle._simplifyTextId,
      _ToolbarActionStyle._askAiId,
      _ToolbarActionStyle._catchMeUpId,
    ],
    [_ToolbarActionStyle._resumeHereId],
  ];

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;

  List<List<ContextMenuButtonItem>> _buildButtonRows() {
    final itemsById = <String, ContextMenuButtonItem>{};
    final usedIds = <String>{};

    for (final item in buttonItems) {
      final actionId = _ToolbarActionStyle._actionIdForItem(item);
      itemsById.putIfAbsent(actionId, () => item);
    }

    final rows = <List<ContextMenuButtonItem>>[];
    for (final rowIds in _kButtonRows) {
      final row = <ContextMenuButtonItem>[];
      for (final rowId in rowIds) {
        final item = itemsById[rowId];
        if (item == null) {
          continue;
        }
        usedIds.add(rowId);
        row.add(item);
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }

    final extraItems = buttonItems.where((item) {
      final actionId = _ToolbarActionStyle._actionIdForItem(item);
      return !usedIds.contains(actionId);
    }).toList();

    for (int i = 0; i < extraItems.length; i += 2) {
      rows.add(extraItems.skip(i).take(2).toList());
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final anchorBelow = anchors.secondaryAnchor ?? anchors.primaryAnchor;
    final anchorAbovePadded =
        anchors.primaryAnchor - const Offset(0, _kToolbarContentDistance);
    final anchorBelowPadded = anchorBelow +
        const Offset(0, TextSelectionToolbar.kToolbarContentDistanceBelow);
    final paddingAbove = MediaQuery.paddingOf(context).top + _kScreenPadding;
    final localAdjustment = Offset(_kScreenPadding, paddingAbove);
    final maxWidth = math.max(
      MediaQuery.sizeOf(context).width - (_kScreenPadding * 2),
      0.0,
    );
    final buttonRows = _buildButtonRows();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kScreenPadding,
        paddingAbove,
        _kScreenPadding,
        _kScreenPadding,
      ),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: anchorAbovePadded - localAdjustment,
          anchorBelow: anchorBelowPadded - localAdjustment,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _ReaderSelectionToolbarContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < buttonRows.length; i++) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int j = 0; j < buttonRows[i].length; j++) ...[
                          if (j > 0) const SizedBox(width: 6),
                          _ReaderSelectionToolbarButton(
                            label: AdaptiveTextSelectionToolbar.getButtonLabel(
                              context,
                              buttonRows[i][j],
                            ),
                            actionStyle: _ToolbarActionStyle.resolve(
                              theme: Theme.of(context),
                              item: buttonRows[i][j],
                            ),
                            onPressed: buttonRows[i][j].onPressed,
                          ),
                        ],
                      ],
                    ),
                    if (i < buttonRows.length - 1) const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderSelectionToolbarContainer extends StatelessWidget {
  const _ReaderSelectionToolbarContainer({
    required this.child,
  });

  static const ValueKey<String> toolbarKey = ValueKey<String>(
    'reader-selection-toolbar-container',
  );
  static const Color _defaultColorLight = Color(0xffffffff);
  static const Color _defaultColorDark = Color(0xff424242);

  final Widget child;

  static Color _getColor(ColorScheme colorScheme) {
    final isDefaultSurface = switch (colorScheme.brightness) {
      Brightness.light => identical(
          ThemeData().colorScheme.surface,
          colorScheme.surface,
        ),
      Brightness.dark => identical(
          ThemeData.dark().colorScheme.surface,
          colorScheme.surface,
        ),
    };
    if (!isDefaultSurface) {
      return colorScheme.surface;
    }
    return switch (colorScheme.brightness) {
      Brightness.light => _defaultColorLight,
      Brightness.dark => _defaultColorDark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withOpacity(
      theme.brightness == Brightness.dark ? 0.45 : 0.28,
    );
    return Material(
      key: toolbarKey,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(ReaderSelectionToolbar._kToolbarBorderRadius),
        ),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      color: _getColor(theme.colorScheme),
      elevation: 1,
      type: MaterialType.card,
      child: child,
    );
  }
}

class _ReaderSelectionToolbarButton extends StatelessWidget {
  const _ReaderSelectionToolbarButton({
    required this.label,
    required this.actionStyle,
    required this.onPressed,
  });

  final String label;
  final _ToolbarActionStyle actionStyle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: actionStyle.foregroundColor,
          fontWeight:
              actionStyle.isAiAction ? FontWeight.w600 : FontWeight.w500,
        );

    return Semantics(
      button: true,
      child: Material(
        key: ValueKey<String>('reader-selection-button-${actionStyle.id}'),
        color: actionStyle.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: actionStyle.borderColor,
            width: actionStyle.isAiAction ? 1.2 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(label, style: textStyle),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionStyle {
  const _ToolbarActionStyle({
    required this.id,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.isAiAction,
  });

  final String id;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final bool isAiAction;

  static const String _copyId = 'copy';
  static const String _highlightId = 'highlight';
  static const String _defineAndTranslateId = 'define_and_translate';
  static const String _generateImageId = 'generate_image';
  static const String _simplifyTextId = 'simplify_text';
  static const String _askAiId = 'ask_ai';
  static const String _resumeHereId = 'resume_here';
  static const String _catchMeUpId = 'catch_me_up';
  static const Color _defineAndTranslateLight = Color(0xFF0B57D0);
  static const Color _defineAndTranslateDark = Color(0xFF8AB4F8);
  static const Color _generateImageLight = Color(0xFF6A1B9A);
  static const Color _generateImageDark = Color(0xFFE1BEE7);
  static const Color _simplifyTextLight = Color(0xFF2E7D32);
  static const Color _simplifyTextDark = Color(0xFF81C995);
  static const Color _askAiLight = Color(0xFFAD1457);
  static const Color _askAiDark = Color(0xFFF48FB1);
  static const Color _catchMeUpLight = Color(0xFFEF6C00);
  static const Color _catchMeUpDark = Color(0xFFFFB74D);

  static _ToolbarActionStyle resolve({
    required ThemeData theme,
    required ContextMenuButtonItem item,
  }) {
    final colorScheme = theme.colorScheme;
    final actionId = _actionIdForItem(item);
    final toolbarColor = _ReaderSelectionToolbarContainer._getColor(
      colorScheme,
    );
    final neutralBorderColor = colorScheme.outline.withOpacity(
      theme.brightness == Brightness.dark ? 0.3 : 0.22,
    );
    final neutralForegroundColor = colorScheme.onSurface.withOpacity(0.92);
    final neutralBackgroundColor = Color.alphaBlend(
      colorScheme.onSurface.withOpacity(
        theme.brightness == Brightness.dark ? 0.06 : 0.03,
      ),
      toolbarColor,
    );

    return switch (actionId) {
      _defineAndTranslateId => _accent(
          id: actionId,
          toolbarColor: toolbarColor,
          accentColor: theme.brightness == Brightness.dark
              ? _defineAndTranslateDark
              : _defineAndTranslateLight,
        ),
      _generateImageId => _accent(
          id: actionId,
          toolbarColor: toolbarColor,
          accentColor: theme.brightness == Brightness.dark
              ? _generateImageDark
              : _generateImageLight,
        ),
      _simplifyTextId => _accent(
          id: actionId,
          toolbarColor: toolbarColor,
          accentColor: theme.brightness == Brightness.dark
              ? _simplifyTextDark
              : _simplifyTextLight,
        ),
      _askAiId => _accent(
          id: actionId,
          toolbarColor: toolbarColor,
          accentColor:
              theme.brightness == Brightness.dark ? _askAiDark : _askAiLight,
        ),
      _catchMeUpId => _accent(
          id: actionId,
          toolbarColor: toolbarColor,
          accentColor: theme.brightness == Brightness.dark
              ? _catchMeUpDark
              : _catchMeUpLight,
        ),
      _ => _ToolbarActionStyle(
          id: actionId,
          backgroundColor: neutralBackgroundColor,
          borderColor: neutralBorderColor,
          foregroundColor: neutralForegroundColor,
          isAiAction: false,
        ),
    };
  }

  static _ToolbarActionStyle _accent({
    required String id,
    required Color toolbarColor,
    required Color accentColor,
  }) {
    return _ToolbarActionStyle(
      id: id,
      backgroundColor: Color.alphaBlend(
        accentColor.withOpacity(0.2),
        toolbarColor,
      ),
      borderColor: accentColor.withOpacity(0.78),
      foregroundColor: accentColor,
      isAiAction: true,
    );
  }

  static String _actionIdForItem(ContextMenuButtonItem item) {
    if (item.type == ContextMenuButtonType.copy) {
      return _copyId;
    }

    return switch (item.label) {
      'Highlight' => _highlightId,
      'Define & Translate' => _defineAndTranslateId,
      'Generate Image' => _generateImageId,
      'Simplify Text' => _simplifyTextId,
      'Ask AI' => _askAiId,
      'Resume Here' => _resumeHereId,
      'Catch Me Up' => _catchMeUpId,
      final String label => label
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), ''),
      null => 'custom_action',
    };
  }
}
