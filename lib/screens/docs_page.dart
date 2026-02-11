import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/app_providers.dart';
import '../models/page_model.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_card.dart';

// --- Slash Command Model ---
class SlashCommand {
  final String id;
  final String label;
  final String markdown;
  final String description;
  final IconData icon;
  final int cursorOffset; // How many chars to move cursor back (usually 0, but for block wraps it differs)

  const SlashCommand({
    required this.id,
    required this.label,
    required this.markdown,
    required this.description,
    required this.icon,
    this.cursorOffset = 0,
  });
}

class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({super.key});

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
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
    const SlashCommand(id: 'h1', label: 'Heading 1', markdown: '# ', description: 'Big section heading', icon: Icons.title),
    const SlashCommand(id: 'h2', label: 'Heading 2', markdown: '## ', description: 'Medium section heading', icon: Icons.title),
    const SlashCommand(id: 'h3', label: 'Heading 3', markdown: '### ', description: 'Small section heading', icon: Icons.title),
    const SlashCommand(id: 'bullet', label: 'Bulleted list', markdown: '- ', description: 'Create a simple bulleted list', icon: Icons.format_list_bulleted),
    const SlashCommand(id: 'number', label: 'Numbered list', markdown: '1. ', description: 'Create a list with numbering', icon: Icons.format_list_numbered),
    const SlashCommand(id: 'todo', label: 'To-do list', markdown: '- [ ] ', description: 'Track tasks with a to-do list', icon: Icons.check_box_outlined),
    const SlashCommand(id: 'quote', label: 'Quote', markdown: '> ', description: 'Capture a quote', icon: Icons.format_quote),
    const SlashCommand(id: 'code', label: 'Code', markdown: '```\n\n```', description: 'Capture a code snippet', icon: Icons.code, cursorOffset: -4),
    const SlashCommand(id: 'divider', label: 'Divider', markdown: '---\n', description: 'Visually divide blocks', icon: Icons.horizontal_rule),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredCommands = _allCommands;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Sync controllers when selection changes
  void _syncControllers(PageModel? page) {
    if (page != null && page.id != _activePageId) {
      _activePageId = page.id;
      _titleController.text = page.title;

      // Only update text if it's drastically different to avoid cursor jumping during typing
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

  // --- Slash Command Logic ---

  void _onContentChanged(String text) {
    _save(); // Auto-save

    final selection = _contentController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_isSlashMenuOpen) setState(() => _isSlashMenuOpen = false);
      return;
    }

    final cursor = selection.baseOffset;
    final textBefore = text.substring(0, cursor);

    // Regex: Find a slash that is either at start, or preceded by whitespace/newline
    // Catch characters after slash as query
    final regex = RegExp(r'(?:^|\s|\n)/([a-zA-Z0-9]*)$');
    final match = regex.firstMatch(textBefore);

    if (match != null) {
      final query = match.group(1) ?? '';
      // Calculate where the slash actually starts
      // match.start is start of whole match (including potential space), so check chars
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
      _selectedMenuIndex = 0; // Reset selection
    });
  }

  void _executeCommand(SlashCommand command) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    // Safety check
    if (_slashStartIndex < 0 || _slashStartIndex >= text.length) return;

    // Construct new text
    // 1. Text before the slash
    final before = text.substring(0, _slashStartIndex);
    // 2. Text after the cursor
    final after = text.substring(selection.baseOffset);

    // 3. Insert markdown
    final newText = before + command.markdown + after;

    // 4. Update controller
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + command.markdown.length + command.cursorOffset,
      ),
    );

    // 5. Close menu and focus
    setState(() {
      _isSlashMenuOpen = false;
      _slashQuery = '';
    });
    _contentFocusNode.requestFocus();
    _save(); // Save changes
  }

  // Handle Keyboard Navigation in Menu
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isSlashMenuOpen) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedMenuIndex = (_selectedMenuIndex + 1) % _filteredCommands.length;
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedMenuIndex = (_selectedMenuIndex - 1 + _filteredCommands.length) % _filteredCommands.length;
        });
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
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);
    _syncControllers(selectedPage);

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
      padding: const EdgeInsets.all(24.0),
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
          const SizedBox(height: 16),

          // Tabs (Edit / Preview)
          Container(
            height: 40,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: GlassTheme.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: GlassTheme.accentColor,
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: "Edit"), Tab(text: "Preview")],
            ),
          ),
          const SizedBox(height: 16),

          // Editor / Preview Area with Stack for Menu
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      // Edit Mode
                      Focus(
                        onKeyEvent: _handleKeyEvent,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            maxLines: null,
                            expands: true,
                            scrollController: _scrollController,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5, fontFamily: 'Courier'),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Type / for commands...',
                              hintStyle: TextStyle(color: Colors.white24),
                            ),
                            onChanged: _onContentChanged,
                          ),
                        ),
                      ),

                      // Preview Mode
                      Markdown(
                        data: _contentController.text,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.white70, fontSize: 16),
                          h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                          h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                          h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          code: const TextStyle(backgroundColor: Colors.white10, fontFamily: 'Courier', fontSize: 14),
                          codeblockDecoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          blockquote: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                          blockquoteDecoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4), border: const Border(left: BorderSide(color: Colors.white30, width: 4))),
                        ),
                      ),
                    ],
                  ),

                  // Slash Menu Popup
                  if (_isSlashMenuOpen)
                    Positioned(
                      // Simple positioning: Fixed at bottom left or floating near top if we could track cursor
                      // For robustness without external packages, we'll fix it to the bottom-left of the editor area
                      // or slightly offset if we wanted. A fixed "Command Palette" style is very usable.
                      bottom: 20,
                      left: 20,
                      width: 300,
                      height: 300,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  const Text("Basic blocks", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const Spacer(),
                                  Text(_slashQuery.isEmpty ? "Type to filter" : "'$_slashQuery'", style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _filteredCommands.isEmpty
                                ? const Center(child: Text("No commands found", style: TextStyle(color: Colors.white38)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(4),
                                    itemCount: _filteredCommands.length,
                                    itemBuilder: (context, index) {
                                      final cmd = _filteredCommands[index];
                                      final isSelected = index == _selectedMenuIndex;

                                      return GestureDetector(
                                        onTap: () => _executeCommand(cmd),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? GlassTheme.accentColor.withValues(alpha: 0.2) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.white10),
                                                ),
                                                child: Icon(cmd.icon, size: 18, color: Colors.white),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(cmd.label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                                    Text(cmd.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
          ),

          const SizedBox(height: 8),
          Text(
            "Last updated: ${selectedPage.updatedAt.hour}:${selectedPage.updatedAt.minute.toString().padLeft(2, '0')}",
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
