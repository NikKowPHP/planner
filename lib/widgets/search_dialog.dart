import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../providers/app_providers.dart';
import '../theme/glass_theme.dart';
import '../services/logger.dart';
import 'glass_card.dart';

class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({super.key});

  @override
  ConsumerState<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<SearchDialog> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Force focus request after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FileLogger().log('UI: SearchDialog requesting immediate focus');
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final notifier = ref.read(homeViewProvider.notifier);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                notifier.toggleSearch(),
          },
          child: GlassCard(
            width: 500,
            height: 450,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    onSubmitted: (val) {
                      FileLogger().log(
                        'GESTURE: Search submitted via Enter: $val',
                      );
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search tasks, tags, lists... (Ctrl+K)",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: GlassTheme.accentColor,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38),
                        onPressed: () => notifier.toggleSearch(),
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: results.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: results.entries
                              .map((e) => _buildSection(e.key, e.value))
                              .toList(),
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
        Text("Search everything in Glassy", style: TextStyle(color: Colors.white38)),
      ],
    ),
  );

  Widget _buildSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: GlassTheme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) {
          IconData icon = Icons.help_outline;
          if (item is Task) icon = Icons.check_circle_outline;
          if (item is Habit) icon = Icons.loop;
          if (item is TaskList) icon = Icons.list;
          if (item is Tag) icon = Icons.label_outline;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(icon, size: 16, color: Colors.white38),
            title: Text(_getName(item), style: const TextStyle(color: Colors.white)),
            onTap: () => ref.read(homeViewProvider.notifier).navigateToItem(item),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getName(dynamic item) {
    if (item is Task) {
      return item.title;
    }
    // Habit, TaskList, and Tag all use 'name'
    try {
      return item.name;
    } catch (e) {
      return "Unknown";
    }
  }
}
