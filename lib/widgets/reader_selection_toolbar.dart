import 'dart:math' as math;

import 'package:flutter/material.dart';

List<ContextMenuButtonItem> buildReaderSelectionButtonItems({
  required List<ContextMenuButtonItem> platformItems,
  required VoidCallback onCopy,
  required VoidCallback onHighlight,
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
      label: 'Resume Here',
      onPressed: onResumeHere,
    ),
    ContextMenuButtonItem(
      label: 'Catch Me Up',
      onPressed: onCatchMeUp,
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

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;

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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final buttonItem in buttonItems)
                    TextSelectionToolbarTextButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: buttonItem.onPressed,
                      alignment: Alignment.center,
                      child: Text(
                        AdaptiveTextSelectionToolbar.getButtonLabel(
                          context,
                          buttonItem,
                        ),
                      ),
                    ),
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
    return Material(
      borderRadius: const BorderRadius.all(
        Radius.circular(ReaderSelectionToolbar._kToolbarBorderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: _getColor(theme.colorScheme),
      elevation: 1,
      type: MaterialType.card,
      child: child,
    );
  }
}
