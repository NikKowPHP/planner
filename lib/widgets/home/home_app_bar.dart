import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/glass_theme.dart';
import '../../services/logger.dart';

class HomeAppBar extends ConsumerWidget {
  final VoidCallback? onMenuPressed; // Add this

  const HomeAppBar({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(currentTitleProvider);
    final isLoading = ref.watch(tasksProvider).isLoading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              // Make clickable
              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const ValueKey('search_button'), // Added key for identification
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: 'Search (Ctrl+K)',
              onPressed: () {
                FileLogger().log('GESTURE: Search icon button clicked in HomeAppBar');
                HapticFeedback.lightImpact();
                ref.read(homeViewProvider.notifier).toggleSearch();
              },
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white30,
                  ),
                ),
              ),
            _buildSortMenu(context, ref),
            _buildViewMenu(context, ref),
          ],
        ),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context, WidgetRef ref) {
    final currentGroup = ref.watch(homeViewProvider.select((s) => s.groupBy));
    final currentSort = ref.watch(homeViewProvider.select((s) => s.sortBy));
    final notifier = ref.read(homeViewProvider.notifier);

    return PopupMenuButton<dynamic>(
        icon: const Icon(Icons.swap_vert, color: Colors.white),
        tooltip: 'Sort & Group',
        itemBuilder: (context) => [
          const PopupMenuItem(enabled: false, child: Text('GROUP BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem(
            'Date',
            currentGroup == GroupBy.date,
            () {
              FileLogger().log('GESTURE: Grouping changed to Date');
              notifier.setGroupBy(GroupBy.date);
            },
          ),
          _buildRadioItem(
            'Priority',
            currentGroup == GroupBy.priority,
            () {
              FileLogger().log('GESTURE: Grouping changed to Priority');
              notifier.setGroupBy(GroupBy.priority);
            },
          ),
          _buildRadioItem(
            'List',
            currentGroup == GroupBy.list,
            () {
              FileLogger().log('GESTURE: Grouping changed to List');
              notifier.setGroupBy(GroupBy.list);
            },
          ),
          _buildRadioItem(
            'None',
            currentGroup == GroupBy.none,
            () {
              FileLogger().log('GESTURE: Grouping changed to None');
              notifier.setGroupBy(GroupBy.none);
            },
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(enabled: false, child: Text('SORT BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem(
            'Date',
            currentSort == SortBy.date,
            () {
              FileLogger().log('GESTURE: Sorting changed to Date');
              notifier.setSortBy(SortBy.date);
            },
          ),
          _buildRadioItem(
            'Priority',
            currentSort == SortBy.priority,
            () {
              FileLogger().log('GESTURE: Sorting changed to Priority');
              notifier.setSortBy(SortBy.priority);
            },
          ),
          _buildRadioItem(
            'Title',
            currentSort == SortBy.title,
            () {
              FileLogger().log('GESTURE: Sorting changed to Title');
              notifier.setSortBy(SortBy.title);
            },
          ),
        ],
      );
  }

  Widget _buildViewMenu(BuildContext context, WidgetRef ref) {
    final hideCompleted = ref.watch(
      homeViewProvider.select((s) => s.hideCompleted),
    );
    
    return PopupMenuButton<dynamic>(
        icon: const Icon(Icons.more_horiz, color: Colors.white),
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            checked: hideCompleted,
            value: 'hide',
            child: const Text('Hide Completed'),
            onTap: () {
              FileLogger().log('GESTURE: Hide Completed toggled to ${!hideCompleted}');
              ref.read(homeViewProvider.notifier).toggleHideCompleted();
            },
          ),
        ],
      );
  }

  PopupMenuItem _buildRadioItem(String text, bool selected, VoidCallback onTap) {
    return PopupMenuItem(
      onTap: onTap,
      height: 40,
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? GlassTheme.accentColor : Colors.white38, size: 18),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }
}
