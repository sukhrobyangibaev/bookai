import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/reader_settings.dart';

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
