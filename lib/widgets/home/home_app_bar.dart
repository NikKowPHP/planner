import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/glass_theme.dart';

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

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: const Color(0xFF1E1E1E),
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10),
          ),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ),
      child: PopupMenuButton<dynamic>(
        icon: const Icon(Icons.swap_vert, color: Colors.white),
        tooltip: 'Sort & Group',
        itemBuilder: (context) => [
          const PopupMenuItem(enabled: false, child: Text('GROUP BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem(
            'Date',
            currentGroup == GroupBy.date,
            () => notifier.setGroupBy(GroupBy.date),
          ),
          _buildRadioItem(
            'Priority',
            currentGroup == GroupBy.priority,
            () => notifier.setGroupBy(GroupBy.priority),
          ),
          _buildRadioItem(
            'List',
            currentGroup == GroupBy.list,
            () => notifier.setGroupBy(GroupBy.list),
          ),
          _buildRadioItem(
            'None',
            currentGroup == GroupBy.none,
            () => notifier.setGroupBy(GroupBy.none),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(enabled: false, child: Text('SORT BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem(
            'Date',
            currentSort == SortBy.date,
            () => notifier.setSortBy(SortBy.date),
          ),
          _buildRadioItem(
            'Priority',
            currentSort == SortBy.priority,
            () => notifier.setSortBy(SortBy.priority),
          ),
          _buildRadioItem(
            'Title',
            currentSort == SortBy.title,
            () => notifier.setSortBy(SortBy.title),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMenu(BuildContext context, WidgetRef ref) {
    final hideCompleted = ref.watch(
      homeViewProvider.select((s) => s.hideCompleted),
    );
    
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: const Color(0xFF1E1E1E),
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10),
          ),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ),
      child: PopupMenuButton<dynamic>(
        icon: const Icon(Icons.more_horiz, color: Colors.white),
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            checked: hideCompleted,
            value: 'hide',
            child: const Text('Hide Completed'),
            onTap: () =>
                ref.read(homeViewProvider.notifier).toggleHideCompleted(),
          ),
        ],
      ),
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
