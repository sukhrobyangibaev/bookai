import 'package:flutter/material.dart';

/// Flutter only auto-injects Material scrollbars on desktop, so mobile
/// screens that need an obvious scroll affordance opt in explicitly.
class MobileScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final bool thumbVisibility;

  const MobileScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = false,
  });

  bool _isMobilePlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobilePlatform(Theme.of(context).platform)) {
      return child;
    }

    final hasScrollController =
        controller != null || PrimaryScrollController.maybeOf(context) != null;

    return Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility && hasScrollController,
      thickness: 3,
      radius: const Radius.circular(8),
      child: child,
    );
  }
}
