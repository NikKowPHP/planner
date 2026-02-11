import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';
import '../models/custom_filter.dart';

class GlassSidebar extends StatelessWidget {
  const GlassSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userLists,
    required this.onAddList,
    this.tags = const [],
    this.onAddTag,
    this.customFilters = const [],
    required this.onAddFilter,
    required this.onEditFilter,
    required this.onDeleteFilter,
    this.width, // Add width parameter
  });

  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<dynamic> userLists;
  final VoidCallback onAddList;
  final List<String> tags;
  final VoidCallback? onAddTag;
  final List<CustomFilter> customFilters;
  final VoidCallback onAddFilter;
  final Function(CustomFilter) onEditFilter;
  final Function(CustomFilter) onDeleteFilter;
  final double? width; // Add field

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 250, // Use parameter or default
      height: double.infinity,
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 24,
        right: 16,
      ), // Removed left padding as it sits next to Rail
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            // Removed Logo and App Name (Moved to Rail)
            
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Smart Lists Section
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionHeader(
                        title: "Smart Lists",
                        onAdd: () {},
                      ), // Dummy add, standard header style
                      _SidebarItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'All',
                        isSelected: selectedIndex == 0,
                        onTap: () => onItemSelected(0),
                        count: 4, // Todo: wire up actual counts
                      ),
                      _SidebarItem(
                        icon: Icons.sunny,
                        label: 'Today',
                        isSelected: selectedIndex == 1,
                        onTap: () => onItemSelected(1),
                        count: 6,
                      ),
                      _SidebarItem(
                        icon: Icons.calendar_month,
                        label: 'Next 7 Days',
                        isSelected: selectedIndex == 2,
                        onTap: () => onItemSelected(2),
                        count: 6,
                      ),
                      _SidebarItem(
                        icon: Icons.inbox_rounded,
                        label: 'Inbox',
                        isSelected: selectedIndex == 3,
                        onTap: () => onItemSelected(3),
                        count: 4,
                      ),
                    ]),
                  ),

                  // Filters Section
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _SectionHeader(title: "Filters", onAdd: onAddFilter),
                    ]),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final filter = customFilters[index];
                      final selectionIdx = 4 + index;
                      return GestureDetector(
                        onSecondaryTapUp: (details) => _showFilterContextMenu(
                          context,
                          details.globalPosition,
                          filter,
                        ),
                        child: _SidebarItem(
                          icon: Icons.filter_list,
                          label: filter.name,
                          isSelected: selectedIndex == selectionIdx,
                          onTap: () => onItemSelected(selectionIdx),
                          color: Colors.purpleAccent,
                        ),
                      );
                    }, childCount: customFilters.length),
                  ),

                  // Lists Section
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _SectionHeader(title: "Lists", onAdd: onAddList),
                    ]),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final selectionIdx = 4 + customFilters.length + index;
                      final list = userLists[index];
                      return _SidebarItem(
                        icon: Icons.list,
                        label: list.name,
                        isSelected: selectedIndex == selectionIdx,
                        onTap: () => onItemSelected(selectionIdx),
                        color: list.color != null
                            ? Color(
                                int.parse(list.color!.replaceAll('#', '0xFF')),
                              )
                            : Colors.blueAccent,
                      );
                    }, childCount: userLists.length),
                  ),

                  // Tags Section
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _SectionHeader(title: "Tags", onAdd: onAddTag ?? () {}),
                    ]),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final selectionIdx =
                          4 + customFilters.length + userLists.length + index;
                      return _SidebarItem(
                        icon: Icons.label_outline,
                        label: tags[index],
                        isSelected: selectedIndex == selectionIdx,
                        onTap: () => onItemSelected(selectionIdx),
                        color: Colors.white70,
                      );
                    }, childCount: tags.length),
                  ),

                  // Footer Section
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),
                        _SidebarItem(
                          icon: Icons.check_circle_outline,
                          label: 'Completed', 
                          isSelected: selectedIndex == -1,
                          onTap: () => onItemSelected(-1),
                        ),
                        _SidebarItem(
                          icon: Icons.delete_outline,
                          label: 'Trash', 
                          isSelected: selectedIndex == -2,
                          onTap: () => onItemSelected(-2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterContextMenu(
    BuildContext context,
    Offset position,
    CustomFilter filter,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      items: [
        PopupMenuItem(
          onTap: () => onEditFilter(filter),
          child: const Row(
            children: [
              Icon(Icons.edit, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text("Edit", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => onDeleteFilter(filter),
          child: const Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Delete", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(4),
            child: const Icon(Icons.add, size: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final int? count;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? GlassTheme.accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  color ??
                  (isSelected ? GlassTheme.accentColor : Colors.white70),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (count != null)
              Text(
                count.toString(),
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
