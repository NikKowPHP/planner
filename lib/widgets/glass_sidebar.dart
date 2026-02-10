import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<dynamic> userLists;
  final VoidCallback onAddList;
  final List<String> tags;
  final VoidCallback? onAddTag; // NEW

  const GlassSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userLists,
    required this.onAddList,
    this.tags = const [],
    this.onAddTag, // NEW
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            // Logo
            const Icon(
              Icons.bubble_chart,
              color: Colors.white,
              size: 32,
            )
                .animate()
                .scale(duration: 600.ms),
            const SizedBox(height: 8),
            const Text(
              'Glassy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Standard Items
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _SidebarItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'All',
                        isSelected: selectedIndex == 0,
                        onTap: () => onItemSelected(0),
                        count: 4,
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

                      // Filters Section
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "Filters",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _FilterPlaceholder(),

                      // Lists Section
                      const SizedBox(height: 24),
                      _SectionHeader(title: "Lists", onAdd: onAddList),
                    ]),
                  ),

                  // Lists Dynamic Items
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final selectionIdx = index + 4;
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
                      _SectionHeader(
                        title: "Tags",
                        onAdd: onAddTag ?? () {},
                      ), // Updated to use onAddTag
                      if (tags.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "No tags yet",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ]),
                  ),
                  
                  // Tags Dynamic Items
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final baseIdx = 4 + userLists.length;
                      final selectionIdx = baseIdx + index;
                      return _SidebarItem(
                        icon: Icons.label_outline, // Tag icon
                        label: tags[index],
                        isSelected: selectedIndex == selectionIdx,
                        onTap: () => onItemSelected(selectionIdx),
                        color: Colors.white70,
                      );
                    }, childCount: tags.length),
                  ),

                  // Footer Section (Completed & Trash)
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
                          isSelected:
                              selectedIndex ==
                              -1, // Special index for Completed
                          onTap: () => onItemSelected(-1),
                        ),
                        _SidebarItem(
                          icon: Icons.delete_outline,
                          label: 'Trash', 
                          isSelected:
                              selectedIndex == -2, // Special index for Trash
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

class _FilterPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        "Display tasks filtered by list, date, priority, tag, and more",
        style: TextStyle(color: Colors.white30, fontSize: 12, height: 1.4),
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
  final int? count; // Added count support

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
