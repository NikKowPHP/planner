import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../models/page_model.dart';

class MarkdownSyntaxTextEditingController extends TextEditingController {
  List<PageModel> pages = []; // Added to lookup titles

  MarkdownSyntaxTextEditingController({this.pages = const [], super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final String text = this.text;
    final baseStyle = style ?? const TextStyle(color: Colors.white, fontSize: 16);

    text.splitMapJoin(
      RegExp(r'.*(\n|$)'),
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
    if (line.startsWith('# ')) {
      return TextSpan(
        text: line,
        style: baseStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
      );
    } else if (line.startsWith('## ')) {
      return TextSpan(
        text: line,
        style: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      );
    } else if (line.startsWith('### ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: GlassTheme.accentColor));
    } else if (line.startsWith('> ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(color: Colors.grey, fontStyle: FontStyle.italic));
    } else if (line.startsWith('```') || line.trim().startsWith('    ')) {
      return TextSpan(text: line, style: baseStyle.copyWith(fontFamily: 'Courier', backgroundColor: Colors.white10));
    } else if (line.trimLeft().startsWith('- ')) {
      return TextSpan(
        children: [
          TextSpan(
            text: line.substring(0, line.indexOf('- ') + 2),
            style: baseStyle.copyWith(
              color: GlassTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          _parseInline(line.substring(line.indexOf('- ') + 2), baseStyle),
        ],
      );
    }
    return _parseInline(line, baseStyle);
  }

  TextSpan _parseInline(String text, TextStyle style) {
    final List<TextSpan> spans = [];
    // Pattern: [Title](page:ID)
    final linkRegex = RegExp(r'\[(.*?)\]\(page:([a-f0-9\-]+)\)');
    final boldRegex = RegExp(r'(\*\*|__)(.*?)\1');

    int start = 0;
    while (start < text.length) {
      final matchLink = linkRegex.firstMatch(text.substring(start));
      final matchBold = boldRegex.firstMatch(text.substring(start));

      int? nextIndex;
      Match? winner;
      String type = '';

      if (matchLink != null) {
        nextIndex = start + matchLink.start;
        winner = matchLink;
        type = 'link';
      }

      if (matchBold != null) {
        final boldIndex = start + matchBold.start;
        if (nextIndex == null || boldIndex < nextIndex) {
          nextIndex = boldIndex;
          winner = matchBold;
          type = 'bold';
        }
      }

      if (winner != null && nextIndex != null) {
        if (nextIndex > start) {
          spans.add(
            TextSpan(text: text.substring(start, nextIndex), style: style),
          );
        }

        if (type == 'link') {
          final pageId = winner.group(2);
          // Lookup page title
          String displayTitle = winner.group(1) ?? 'Untitled';
          try {
            final page = pages.firstWhere((p) => p.id == pageId);
            displayTitle = page.title.isEmpty ? 'Untitled' : page.title;
          } catch (_) {}

          // 1. Render the bracketed part with the resolved title
          spans.add(
            TextSpan(
              text: '[$displayTitle]',
              style: style.copyWith(
                color: GlassTheme.accentColor,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          );

          // 2. Render the ID part as "folded" (invisible/tiny) so it's not a mess on screen
          // but still exists in the text buffer for logic and cursor movement.
          spans.add(
            TextSpan(
              text: '(page:$pageId)',
              style: style.copyWith(color: Colors.transparent, fontSize: 0.1),
            ),
          );
        } else if (type == 'bold') {
          spans.add(
            TextSpan(
              text: winner.group(0),
              style: style.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        start = start + winner.end;
      } else {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
    }
    return TextSpan(children: spans);
  }
}
