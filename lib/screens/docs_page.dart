import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/app_providers.dart';
import '../models/page_model.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_card.dart';

class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({super.key});

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  Timer? _debounce;
  String? _activePageId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Sync controllers when selection changes
  void _syncControllers(PageModel? page) {
    if (page != null && page.id != _activePageId) {
      _activePageId = page.id;
      _titleController.text = page.title;
      _contentController.text = page.content;
    }
  }

  void _onChanged() {
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

  @override
  Widget build(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);
    _syncControllers(selectedPage);

    if (selectedPage == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article, size: 64, color: Colors.white10),
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
            onChanged: (_) => _onChanged(),
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

          // Editor / Preview Area
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(4),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Edit Mode
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5, fontFamily: 'Courier'),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type / to insert... (Markdown supported)',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      onChanged: (_) => _onChanged(),
                    ),
                  ),
                  
                  // Preview Mode
                  Markdown(
                    data: _contentController.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white70, fontSize: 16),
                      h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      code: const TextStyle(backgroundColor: Colors.white10, fontFamily: 'Courier', fontSize: 14),
                      codeblockDecoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      blockquote: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      blockquoteDecoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4), border: const Border(left: BorderSide(color: Colors.white30, width: 4))),
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
