import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

class MarkdownSyntaxTextEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final String text = this.text;

    // Base Style
    final baseStyle = style ?? const TextStyle(color: Colors.white, fontSize: 16);

    // Split into lines to apply block styles
    text.splitMapJoin(
      RegExp(r'.*(\n|$)'), // Match lines
      onMatch: (m) {
        final line = m.group(0)!;
        children.add(_parseLine(line, baseStyle));
        return '';
      },
      onNonMatch: (s) => '',
    );

    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _parseLine(String line, TextStyle baseStyle) {
    // Headers
    if (line.startsWith('# ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white));
    } else if (line.startsWith('## ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white));
    } else if (line.startsWith('### ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: GlassTheme.accentColor));
    }

    // Blockquotes
    else if (line.startsWith('> ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(color: Colors.grey, fontStyle: FontStyle.italic));
    }

    // Code Blocks (Basic detection)
    else if (line.startsWith('```') || line.trim().startsWith('    ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontFamily: 'Courier', backgroundColor: Colors.white10));
    }

    // Bullet Points
    else if (line.trimLeft().startsWith('- ')) {
       return TextSpan(
         children: [
           TextSpan(text: line.substring(0, line.indexOf('- ') + 2), style: baseStyle.copyWith(color: GlassTheme.accentColor, fontWeight: FontWeight.bold)),
           TextSpan(text: line.substring(line.indexOf('- ') + 2), style: baseStyle),
         ],
       );
    }

    // Default: Parse inline styles (bold/italic) roughly
    return TextSpan(children: _parseInline(line, baseStyle));
  }

  List<TextSpan> _parseInline(String text, TextStyle style) {
    // Very basic inline bold parser (**text**)
    final List<TextSpan> spans = [];
    final regex = RegExp(r'(\*\*|__)(.*?)\1');

    int start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      spans.add(TextSpan(text: match.group(2), style: style.copyWith(fontWeight: FontWeight.bold)));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }
}
