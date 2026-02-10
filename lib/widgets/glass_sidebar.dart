import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<dynamic>
  userLists; // Using dynamic because TaskList might not be imported here, ideally import it
  final VoidCallback onAddList;

  const GlassSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userLists,
    required this.onAddList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            // Logo / Brand
            const Icon(Icons.bubble_chart, color: Colors.white, size: 48)
                .animate()
                .scale(duration: 600.ms),
            const SizedBox(height: 16),
            Text(
              'Glassy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 48),

            // Navigation Items
            _SidebarItem(
              icon: Icons.calendar_today_rounded,
              label: 'All',
              // count: 3, // Logic for counts needs to be passed down or calculated
              isSelected: selectedIndex == 0,
              onTap: () => onItemSelected(0),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.sunny,
              label: 'Today',
              isSelected: selectedIndex == 1,
              onTap: () => onItemSelected(1),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.calendar_month,
              label: 'Next 7 Days',
              isSelected: selectedIndex == 2,
              onTap: () => onItemSelected(2),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.inbox_rounded,
              label: 'Inbox',
              isSelected: selectedIndex == 3,
              onTap: () => onItemSelected(3),
            ),
            const SizedBox(height: 8),
            // _SidebarItem(
            //   icon: Icons.article_outlined,
            //   label: 'Summary',
            //   isSelected: selectedIndex == 4,
            //   onTap: () => onItemSelected(4),
            // ),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Lists",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: Colors.white54),
                  onPressed: onAddList,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // User Lists
            Expanded(
              child: ListView.builder(
                itemCount: userLists.length,
                itemBuilder: (context, index) {
                  // Offset index by fixed items count (4: All, Today, Next7, Inbox)
                  // If Summary is kept, offset is 5. Removing Summary for now as per plan/simplification.
                  final selectionIdx = index + 4;
                  final list = userLists[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _SidebarItem(
                      icon: Icons.list, // Or custom icon from list.icon
                      label: list.name,
                      isSelected: selectedIndex == selectionIdx,
                      onTap: () => onItemSelected(selectionIdx),
                      color: list.color != null
                          ? Color(
                              int.parse(list.color!.replaceAll('#', '0xFF')),
                            )
                          : Colors.blueAccent,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
