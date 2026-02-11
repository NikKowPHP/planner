import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/page_model.dart';
import '../theme/glass_theme.dart';
import '../widgets/responsive_layout.dart';
import '../utils/markdown_controller.dart';

// --- Slash Command Model ---
class SlashCommand {
  final String id;
  final String label;
  final String markdown;
  final String description;
  final IconData icon;
  final int cursorOffset;
  final bool isAction; // New: Distinguish between text insert vs function

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

class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({super.key});

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage> {
  final TextEditingController _titleController = TextEditingController();

  // Use the custom controller - initialized in initState
  late MarkdownSyntaxTextEditingController _contentController;

  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  String? _activePageId;

  // Slash Menu State
  bool _isSlashMenuOpen = false;
  String _slashQuery = '';
  int _slashStartIndex = -1;
  int _selectedMenuIndex = 0;
  List<SlashCommand> _filteredCommands = [];

  // Available Commands
  final List<SlashCommand> _allCommands = [
    const SlashCommand(id: 'text', label: 'Text', markdown: '', description: 'Just plain text', icon: Icons.text_fields),
    const SlashCommand(
      id: 'page',
      label: 'Page',
      markdown: '',
      description: 'Embed a sub-page',
      icon: Icons.article_outlined,
      isAction: true,
    ), // New
    const SlashCommand(id: 'h1', label: 'Heading 1', markdown: '# ', description: 'Big section heading', icon: Icons.title),
    const SlashCommand(id: 'h2', label: 'Heading 2', markdown: '## ', description: 'Medium section heading', icon: Icons.title),
    const SlashCommand(id: 'h3', label: 'Heading 3', markdown: '### ', description: 'Small section heading', icon: Icons.title),
    const SlashCommand(id: 'bullet', label: 'Bulleted list', markdown: '- ', description: 'Create a simple bulleted list', icon: Icons.format_list_bulleted),
    const SlashCommand(id: 'number', label: 'Numbered list', markdown: '1. ', description: 'Create a list with numbering', icon: Icons.format_list_numbered),
    const SlashCommand(
      id: 'todo',
      label: 'To-do list',
      markdown: '- [ ] ',
      description: 'Track tasks with a to-do list',
      icon: Icons.check_box_outlined,
    ),
    const SlashCommand(id: 'code', label: 'Code', markdown: '```\n\n```', description: 'Capture a code snippet', icon: Icons.code, cursorOffset: -4),
    const SlashCommand(
      id: 'quote',
      label: 'Quote',
      markdown: '> ',
      description: 'Capture a quote',
      icon: Icons.format_quote,
    ),
    const SlashCommand(id: 'divider', label: 'Divider', markdown: '---\n', description: 'Visually divide blocks', icon: Icons.horizontal_rule),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize filtered commands
    _filteredCommands = _allCommands;

    // MODIFIED: Controller no longer needs a callback
    _contentController = MarkdownSyntaxTextEditingController();
  }

  // NEW METHOD: Detects if the tap occurred inside a [link](page:id)
  void _handleEditorTap() {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (!selection.isValid || !selection.isCollapsed) return;

    final cursor = selection.baseOffset;
    final linkRegex = RegExp(r'\[.*?\]\(page:([a-f0-9\-]+)\)');

    // Find all links and check if cursor is inside one
    for (final match in linkRegex.allMatches(text)) {
      if (cursor >= match.start && cursor <= match.end) {
        final pageId = match.group(1);
        if (pageId != null) {
          _handleLinkTap(pageId);
        }
        break;
      }
    }
  }

  // Updated handler (Logic stays same, triggered differently)
  void _handleLinkTap(String pageId) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;

    final isCtrl =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);

    if (!isDesktop || isCtrl) {
      final pages = ref.read(pagesProvider).value ?? [];
      try {
        pages.firstWhere((p) => p.id == pageId);
        ref.read(selectedPageIdProvider.notifier).state = pageId;
        _contentFocusNode.unfocus(); // Ensure view updates
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Page not found')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _syncControllers(PageModel? page) {
    if (page != null && page.id != _activePageId) {
      _activePageId = page.id;
      _titleController.text = page.title;
      if (_contentController.text != page.content) {
        _contentController.text = page.content;
      }
    }
  }

  void _save() {
    if (_activePageId == null) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(pagesProvider.notifier).updatePage(
        _activePageId!,
        title: _titleController.text,
        content: _contentController.text,
      );
    });
  }

  // --- Slash Command & Editor Logic ---

  void _onContentChanged(String text) {
    _save();

    final selection = _contentController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_isSlashMenuOpen) setState(() => _isSlashMenuOpen = false);
      return;
    }

    final cursor = selection.baseOffset;
    final textBefore = text.substring(0, cursor);

    // Detect slash at start of line or after space
    final regex = RegExp(r'(?:^|\s|\n)/([a-zA-Z0-9]*)$');
    final match = regex.firstMatch(textBefore);

    if (match != null) {
      final query = match.group(1) ?? '';
      final rawMatch = match.group(0)!;
      final slashIndex = match.start + (rawMatch.contains('/') ? rawMatch.indexOf('/') : 0);

      setState(() {
        _isSlashMenuOpen = true;
        _slashQuery = query;
        _slashStartIndex = slashIndex;
        _filterCommands(query);
      });
    } else {
      if (_isSlashMenuOpen) setState(() => _isSlashMenuOpen = false);
    }
  }

  void _filterCommands(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filteredCommands = _allCommands.where((cmd) {
        return cmd.label.toLowerCase().contains(lower) ||
               cmd.id.contains(lower);
      }).toList();
      _selectedMenuIndex = 0;
    });
  }

  Future<void> _executeCommand(SlashCommand command) async {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (_slashStartIndex < 0 || _slashStartIndex >= text.length) return;

    // 1. Remove the slash command query text (e.g. "/hea")
    final before = text.substring(0, _slashStartIndex);
    final after = text.substring(selection.baseOffset);

    // 2. Handle Actions vs Text Insertion
    String insertion = command.markdown;
    int offset = command.cursorOffset;

    if (command.isAction) {
      if (command.id == 'page') {
        // Create sub-page
        await _createSubPage(before, after);
        return;
      }
    }

    // 3. Insert Markdown
    final newText = before + insertion + after;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + insertion.length + offset,
      ),
    );

    setState(() {
      _isSlashMenuOpen = false;
      _slashQuery = '';
    });
    _contentFocusNode.requestFocus();
    _save();
  }

  // Updated create sub-page logic to fix content copying bug
  Future<void> _createSubPage(String before, String after) async {
    if (_activePageId == null) return;

    // 1. Create page in DB but DO NOT switch to it (shouldSelect: false)
    final newPage = await ref
        .read(pagesProvider.notifier)
        .createPage(parentId: _activePageId, shouldSelect: false);

    // 2. Insert Link using the returned ID
    final linkText = '[Untitled](page:${newPage.id}) ';
    final newText = before + linkText + after;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + linkText.length,
      ),
    );

    setState(() {
      _isSlashMenuOpen = false;
      _slashQuery = '';
    });
    _contentFocusNode.requestFocus();
    _save();
  }

  void _insertText(String textToInsert) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) return;

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      textToInsert,
    );
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.baseOffset + textToInsert.length,
      ),
    );
    _onContentChanged(newText);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Slash Menu Navigation
      if (_isSlashMenuOpen) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(
            () => _selectedMenuIndex =
                (_selectedMenuIndex + 1) % _filteredCommands.length,
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(
            () => _selectedMenuIndex =
                (_selectedMenuIndex - 1 + _filteredCommands.length) %
                _filteredCommands.length,
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_filteredCommands.isNotEmpty) {
            _executeCommand(_filteredCommands[_selectedMenuIndex]);
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _isSlashMenuOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored; // Let input handle text
      }

      // Auto-continue List
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final text = _contentController.text;
        final selection = _contentController.selection;

        if (selection.isValid && selection.isCollapsed) {
          final cursor = selection.baseOffset;
          int lineStart = text.lastIndexOf('\n', cursor - 1);
          lineStart = (lineStart == -1) ? 0 : lineStart + 1;

          final currentLine = text.substring(lineStart, cursor);

          // Checkboxes
          final checkboxMatch = RegExp(
            r'^(\s*)-\s\[[xX ]?\]\s',
          ).firstMatch(currentLine);
          if (checkboxMatch != null) {
            if (currentLine.trim() == '- [ ]' ||
                currentLine.trim() == '- [x]') {
              // Empty item, break list
              _contentController.value = TextEditingValue(
                text: text.replaceRange(lineStart, cursor, ''),
                selection: TextSelection.collapsed(offset: lineStart),
              );
            } else {
              _insertText('\n${checkboxMatch.group(1)}- [ ] ');
            }
            return KeyEventResult.handled;
          }

          // Bullets
          final bulletMatch = RegExp(
            r'^(\s*)([-*+])\s',
          ).firstMatch(currentLine);
          if (bulletMatch != null) {
            if (currentLine.trim() == bulletMatch.group(2)) {
              _contentController.value = TextEditingValue(
                text: text.replaceRange(lineStart, cursor, ''),
                selection: TextSelection.collapsed(offset: lineStart),
              );
            } else {
              _insertText('\n${bulletMatch.group(1)}${bulletMatch.group(2)} ');
            }
            return KeyEventResult.handled;
          }

          // Numbers
          final numberMatch = RegExp(
            r'^(\s*)(\d+)\.\s',
          ).firstMatch(currentLine);
          if (numberMatch != null) {
            if (currentLine.trim() == '${numberMatch.group(2)}.') {
              _contentController.value = TextEditingValue(
                text: text.replaceRange(lineStart, cursor, ''),
                selection: TextSelection.collapsed(offset: lineStart),
              );
            } else {
              final nextNum = (int.tryParse(numberMatch.group(2)!) ?? 0) + 1;
              _insertText('\n${numberMatch.group(1)}$nextNum. ');
            }
            return KeyEventResult.handled;
          }
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);
    final allPages = ref.watch(pagesProvider).value ?? [];

    _syncControllers(selectedPage);

    // Update controller's page list so it can resolve titles
    _contentController.pages = allPages;

    if (selectedPage == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text('Select a page or create a new one', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Input
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Untitled',
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none,
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 8),

          // Metadata line
          Text(
            "Last updated: ${selectedPage.updatedAt.hour}:${selectedPage.updatedAt.minute.toString().padLeft(2, '0')}",
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),

          const SizedBox(height: 24),

          // Single Unified Editor with Stack for Slash Menu
          Expanded(
            child: Stack(
              children: [
                // The Editor
                Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller:
                        _contentController, // Uses MarkdownSyntaxTextEditingController
                    focusNode: _contentFocusNode,
                    maxLines: null,
                    expands: true,
                    scrollController: _scrollController,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                    ),
                    cursorColor: GlassTheme.accentColor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type / for commands...',
                      hintStyle: TextStyle(color: Colors.white24),
                      contentPadding: EdgeInsets.only(
                        bottom: 200,
                      ), // Space for slash menu at bottom
                    ),
                    onChanged: _onContentChanged,
                    onTap: _handleEditorTap, // NEW: Handle link navigation here
                  ),
                ),

                // Slash Menu Popup
                if (_isSlashMenuOpen)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    width: 300,
                    height: 320,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white10),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  "Blocks",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _slashQuery.isEmpty
                                      ? "Type to filter"
                                      : "'$_slashQuery'",
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _filteredCommands.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No commands found",
                                      style: TextStyle(color: Colors.white38),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(6),
                                    itemCount: _filteredCommands.length,
                                    itemBuilder: (context, index) {
                                      final cmd = _filteredCommands[index];
                                      final isSelected =
                                          index == _selectedMenuIndex;

                                      return GestureDetector(
                                        onTap: () => _executeCommand(cmd),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? GlassTheme.accentColor
                                                      .withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.white10,
                                                  ),
                                                ),
                                                child: Icon(
                                                  cmd.icon,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cmd.label,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      cmd.description,
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
