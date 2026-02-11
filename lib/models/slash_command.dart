import 'package:flutter/material.dart';

/// Model representing a slash command in the Docs editor
class SlashCommand {
  final String id;
  final String label;
  final String markdown;
  final String description;
  final IconData icon;
  final int cursorOffset;
  final bool isAction;

  const SlashCommand({
    required this.id,
    required this.label,
    required this.markdown,
    required this.description,
    required this.icon,
    this.cursorOffset = 0,
    this.isAction = false,
  });
}
