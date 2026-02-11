import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_match.dart';
import '../models/habit.dart';
import '../models/page_model.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../providers/app_providers.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({super.key});

  @override
  ConsumerState<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<SearchDialog> {
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Helper: Flatten Map to List for UI ---
  List<dynamic> _buildFlatList(Map<String, List<dynamic>> results) {
    final flatList = <dynamic>[];
    results.forEach((key, values) {
      if (values.isNotEmpty) {
        flatList.add(_SectionHeader(key));
        flatList.addAll(values);
      }
    });
    return flatList;
  }

  // --- Helper: Get only selectable items for logic ---
  List<dynamic> _getSelectableItems(Map<String, List<dynamic>> results) {
    return results.values.expand((x) => x).toList();
  }

  // --- Keyboard Handler ---
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final results = ref.read(searchResultsProvider);
      final selectables = _getSelectableItems(results);

      if (selectables.isEmpty) return KeyEventResult.ignored;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % selectables.length;
        });
        _scrollToSelected(results);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + selectables.length) % selectables.length;
        });
        _scrollToSelected(results);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        ref
            .read(homeViewProvider.notifier)
            .navigateToItem(selectables[_selectedIndex]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected(Map<String, List<dynamic>> results) {
    // Calculate approximate position
    // Header ~ 30px, Item ~ 50px (dense list tile)
    const headerHeight = 35.0;
    const itemHeight = 56.0;

    double offset = 0;
    int currentSelectableCount = 0;

    for (var entry in results.entries) {
      offset += headerHeight; // Add section header height

      // Check if our selected index is within this section
      if (_selectedIndex < currentSelectableCount + entry.value.length) {
        // It's in this section
        final indexInSection = _selectedIndex - currentSelectableCount;
        offset += indexInSection * itemHeight;
        break;
      }

      // Not in this section, add full height of this section
      offset += entry.value.length * itemHeight;
      currentSelectableCount += entry.value.length;
    }

    // Scroll to keep it visible (centering logic)
    const double viewportHeight = 400; // Approx height of list area
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      if (offset < currentOffset) {
        _scrollController.jumpTo(offset);
      } else if (offset + itemHeight > currentOffset + viewportHeight) {
        _scrollController.jumpTo(offset + itemHeight - viewportHeight);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsMap = ref.watch(searchResultsProvider);
    final flatList = _buildFlatList(resultsMap);

    // Reset index if out of bounds (e.g. search query changed results)
    final totalSelectables = _getSelectableItems(resultsMap).length;
    if (_selectedIndex >= totalSelectables && totalSelectables > 0) {
      _selectedIndex = 0;
    }

    // Map the linear selected index to the specific item object for highlighting
    final selectables = _getSelectableItems(resultsMap);
    final selectedItem = selectables.isNotEmpty
        ? selectables[_selectedIndex]
        : null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                ref.read(homeViewProvider.notifier).toggleSearch(),
          },
          child: GlassCard(
            width: 600,
            height: 500,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Search Input with Key Interception
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "Search tasks, notes, commands...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: GlassTheme.accentColor,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white38),
                          onPressed: () => ref
                              .read(homeViewProvider.notifier)
                              .toggleSearch(),
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        ref.read(homeViewProvider.notifier).setSearchQuery(val);
                        setState(
                          () => _selectedIndex = 0,
                        ); // Reset selection on type
                      },
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                
                // Results List
                Expanded(
                  child: flatList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: flatList.length,
                          itemBuilder: (context, index) {
                            final item = flatList[index];
                            if (item is _SectionHeader) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  16,
                                  12,
                                  8,
                                ),
                                child: Text(
                                  item.title.toUpperCase(),
                                  style: const TextStyle(
                                    color: GlassTheme.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              );
                            } else {
                              final isSelected = item == selectedItem;
                              return _SearchResultTile(
                                item: item,
                                isSelected: isSelected,
                                onTap: () => ref
                                    .read(homeViewProvider.notifier)
                                    .navigateToItem(item),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.manage_search, size: 64, color: Colors.white10),
        SizedBox(height: 16),
        Text("Type to search...", style: TextStyle(color: Colors.white38)),
      ],
    ),
  );
}

// Helper classes for the flat list
class _SectionHeader {
  final String title;
  _SectionHeader(this.title);
}

class _SearchResultTile extends StatelessWidget {
  final dynamic item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.article_outlined;
    String title = "Unknown";
    String? subtitle;

    if (item is Task) {
      icon = Icons.check_circle_outline;
      title = item.title;
      if (item.description != null && item.description!.isNotEmpty) {
        subtitle = item.description;
      }
    } else if (item is Habit) {
      icon = Icons.loop;
      title = item.name;
    } else if (item is TaskList) {
      icon = Icons.list;
      title = item.name;
    } else if (item is Tag) {
      icon = Icons.label_outline;
      title = item.name;
    } else if (item is PageModel) {
      icon = Icons.article;
      title = item.title.isEmpty ? "Untitled" : item.title;
    } else if (item is ContentMatch) {
      icon = Icons.text_snippet;
      title = item.page.title.isEmpty ? "Untitled" : item.page.title;
      subtitle = item.snippet;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? GlassTheme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? GlassTheme.accentColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          leading: Icon(
            icon,
            size: 20,
            color: isSelected ? GlassTheme.accentColor : Colors.white54,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: isSelected
              ? const Icon(
                  Icons.keyboard_return,
                  size: 16,
                  color: Colors.white30,
                )
              : null,
        ),
      ),
    );
  }
}
