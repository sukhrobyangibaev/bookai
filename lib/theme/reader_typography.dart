import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/reader_settings.dart';

const double readerContentLineHeight = 1.6;

TextStyle applyReaderFont({
  required TextStyle baseStyle,
  required ReaderFontFamily fontFamily,
}) {
  switch (fontFamily) {
    case ReaderFontFamily.system:
      return baseStyle;
    case ReaderFontFamily.literata:
      return GoogleFonts.literata(textStyle: baseStyle);
    case ReaderFontFamily.bitter:
      return GoogleFonts.bitter(textStyle: baseStyle);
    case ReaderFontFamily.atkinsonHyperlegible:
      return GoogleFonts.atkinsonHyperlegible(textStyle: baseStyle);
  }
}

TextStyle buildReaderContentTextStyle({
  required BuildContext context,
  required double fontSize,
  required ReaderFontFamily fontFamily,
}) {
  final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: fontSize,
            height: readerContentLineHeight,
          ) ??
      TextStyle(
        fontSize: fontSize,
        height: readerContentLineHeight,
      );

  return applyReaderFont(
    baseStyle: baseStyle,
    fontFamily: fontFamily,
  );
}
