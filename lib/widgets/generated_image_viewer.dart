import 'dart:io';

import 'package:flutter/material.dart';

Future<void> showGeneratedImageViewer(
  BuildContext context, {
  required String filePath,
  String title = 'Generated Image',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _GeneratedImageViewerScreen(
        filePath: filePath,
        title: title,
      ),
    ),
  );
}

class ZoomableGeneratedImagePreview extends StatelessWidget {
  const ZoomableGeneratedImagePreview({
    super.key,
    required this.filePath,
    this.viewerTitle = 'Generated Image',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.imageKey,
  });

  final String filePath;
  final String viewerTitle;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showGeneratedImageViewer(
            context,
            filePath: filePath,
            title: viewerTitle,
          ),
          child: Container(
            width: width,
            height: height,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(filePath),
                  key: imageKey,
                  fit: fit,
                  errorBuilder: (context, error, stackTrace) {
                    return _GeneratedImageFallback(
                      iconColor: theme.colorScheme.onSurfaceVariant,
                    );
                  },
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child: _ZoomBadge(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GeneratedImageFileSizeText extends StatelessWidget {
  const GeneratedImageFileSizeText({
    super.key,
    required this.filePath,
    this.label = 'File size',
    this.style,
  });

  final String filePath;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final formattedSize = _loadFormattedFileSize(filePath);
    if (formattedSize == null) {
      return const SizedBox.shrink();
    }

    return Text(
      '$label: $formattedSize',
      style: style,
    );
  }
}

class _GeneratedImageViewerScreen extends StatelessWidget {
  const _GeneratedImageViewerScreen({
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            key: const ValueKey<String>('generated-image-viewer'),
            clipBehavior: Clip.none,
            maxScale: 5,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: Image.file(
                  File(filePath),
                  key: const ValueKey<String>('generated-image-viewer-image'),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const _GeneratedImageFallback(
                      iconColor: Colors.white70,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GeneratedImageFallback extends StatelessWidget {
  const _GeneratedImageFallback({
    required this.iconColor,
  });

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: iconColor,
        size: 40,
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.zoom_in_outlined,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}

String? _loadFormattedFileSize(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return null;
  }

  try {
    return _formatFileSize(file.lengthSync());
  } on FileSystemException {
    return null;
  }
}

String _formatFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  if (unitIndex == 0) {
    return '${value.toInt()} ${units[unitIndex]}';
  }

  final fixed =
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  final trimmed =
      fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  return '$trimmed ${units[unitIndex]}';
}
