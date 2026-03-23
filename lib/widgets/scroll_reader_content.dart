import 'package:flutter/material.dart';

import 'mobile_scrollbar.dart';

class ScrollReaderContent extends StatelessWidget {
  final ScrollController scrollController;
  final EdgeInsetsGeometry padding;
  final Widget? previousChapterButton;
  final String chapterTitle;
  final TextSpan chapterText;
  final TextStyle chapterTextStyle;
  final EditableTextContextMenuBuilder contextMenuBuilder;
  final Widget chapterEndActions;

  const ScrollReaderContent({
    super.key,
    required this.scrollController,
    required this.padding,
    this.previousChapterButton,
    required this.chapterTitle,
    required this.chapterText,
    required this.chapterTextStyle,
    required this.contextMenuBuilder,
    required this.chapterEndActions,
  });

  @override
  Widget build(BuildContext context) {
    return MobileScrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previousChapterButton != null) ...[
              previousChapterButton!,
              const SizedBox(height: 16),
            ],
            Text(
              chapterTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SelectableText.rich(
              chapterText,
              textAlign: TextAlign.justify,
              style: chapterTextStyle,
              contextMenuBuilder: contextMenuBuilder,
            ),
            const SizedBox(height: 24),
            chapterEndActions,
          ],
        ),
      ),
    );
  }
}
