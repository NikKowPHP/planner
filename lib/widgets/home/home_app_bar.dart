import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_provider.dart';
import '../../theme/glass_theme.dart';
import '../../services/logger.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HomeProvider>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title
        Row(
          children: [
            const Icon(Icons.menu, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(
              provider.currentTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        // Actions
        Row(
          children: [
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                ),
              ),
              
            // Sort/Group Menu
            _buildSortMenu(context, provider),
            
            // View Options
            _buildViewMenu(context, provider),
          ],
        ),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context, HomeProvider provider) {
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
        onOpened: () => FileLogger().log('UI: Sort menu opened'),
        itemBuilder: (context) => [
          const PopupMenuItem(enabled: false, child: Text('GROUP BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem('Date', provider.groupBy == GroupBy.date, () => provider.setGroupBy(GroupBy.date)),
          _buildRadioItem('Priority', provider.groupBy == GroupBy.priority, () => provider.setGroupBy(GroupBy.priority)),
          _buildRadioItem('List', provider.groupBy == GroupBy.list, () => provider.setGroupBy(GroupBy.list)),
          _buildRadioItem('None', provider.groupBy == GroupBy.none, () => provider.setGroupBy(GroupBy.none)),
          const PopupMenuDivider(),
          const PopupMenuItem(enabled: false, child: Text('SORT BY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          _buildRadioItem('Date', provider.sortBy == SortBy.date, () => provider.setSortBy(SortBy.date)),
          _buildRadioItem('Priority', provider.sortBy == SortBy.priority, () => provider.setSortBy(SortBy.priority)),
          _buildRadioItem('Title', provider.sortBy == SortBy.title, () => provider.setSortBy(SortBy.title)),
        ],
      ),
    );
  }

  Widget _buildViewMenu(BuildContext context, HomeProvider provider) {
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
        tooltip: 'View Options',
        onOpened: () => FileLogger().log('UI: View options menu opened'),
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            checked: provider.hideCompleted,
            value: 'hide',
            onTap: provider.toggleHideCompleted,
            child: const Text('Hide Completed'),
          ),
          PopupMenuItem(
            onTap: () =>
                FileLogger().log('UI: Print requested (not implemented)'),
            child: const Row(
              children: [Icon(Icons.print, size: 18, color: Colors.white70), SizedBox(width: 12), Text('Print')],
            ),
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
