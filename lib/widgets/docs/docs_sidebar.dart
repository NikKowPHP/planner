import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../models/page_model.dart';
import '../glass_card.dart';
import '../../theme/glass_theme.dart';

class DocsSidebar extends ConsumerWidget {
  final double width;
  const DocsSidebar({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(pagesProvider);
    final selectedId = ref.watch(selectedPageIdProvider);

    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Workspace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, color: Colors.white70, size: 20),
                  tooltip: 'New Page',
                  onPressed: () => ref.read(pagesProvider.notifier).createPage(),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            
            // Tree View
            Expanded(
              child: pagesAsync.when(
                data: (allPages) {
                  // Find root pages (parentId is null)
                  final rootPages = allPages.where((p) => p.parentId == null).toList();
                  
                  return ListView.builder(
                    itemCount: rootPages.length,
                    itemBuilder: (context, index) {
                      return _PageTreeNode(
                        page: rootPages[index],
                        allPages: allPages,
                        selectedId: selectedId,
                        depth: 0,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white38, fontSize: 10))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTreeNode extends ConsumerWidget {
  final PageModel page;
  final List<PageModel> allPages;
  final String? selectedId;
  final int depth;

  const _PageTreeNode({
    required this.page,
    required this.allPages,
    required this.selectedId,
    required this.depth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = allPages.where((p) => p.parentId == page.id).toList();
    final isSelected = selectedId == page.id;
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Row
        GestureDetector(
          onTap: () {
            ref.read(selectedPageIdProvider.notifier).state = page.id;
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? GlassTheme.accentColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: depth * 12),
                // Expand Toggle
                if (hasChildren)
                  GestureDetector(
                    onTap: () => ref.read(pagesProvider.notifier).toggleExpand(page.id),
                    child: Icon(
                      page.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      color: Colors.white54,
                      size: 16,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                
                const SizedBox(width: 4),
                const Icon(Icons.article_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    page.title.isEmpty ? 'Untitled' : page.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                
                // Add Sub-page button (show on hover/selection usually, simplified here)
                if (isSelected)
                  GestureDetector(
                    onTap: () => _showContextMenu(context, ref),
                    child: const Icon(Icons.more_horiz, color: Colors.white38, size: 14),
                  ),
              ],
            ),
          ),
        ),

        // Recursive Children
        if (page.isExpanded && hasChildren)
          ...children.map((child) => _PageTreeNode(
                page: child,
                allPages: allPages,
                selectedId: selectedId,
                depth: depth + 1,
              )),
      ],
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pagesProvider.notifier);
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx + 100, position.dy, 0, 0),
      color: const Color(0xFF1E1E1E),
      items: [
        PopupMenuItem(
          onTap: () => notifier.createPage(parentId: page.id),
          child: const Row(children: [Icon(Icons.add, size: 16, color: Colors.white), SizedBox(width: 8), Text("Add Sub-page", style: TextStyle(color: Colors.white))]),
        ),
        PopupMenuItem(
          onTap: () => notifier.deletePage(page.id),
          child: const Row(children: [Icon(Icons.delete, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.redAccent))]),
        ),
      ],
    );
  }
}
