import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const GlassSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
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
              icon: Icons
                  .calendar_today_rounded, // Changed icon for "All" (or similar)
              label: 'All',
              count: 3, // Mock count
              isSelected: selectedIndex == 0,
              onTap: () => onItemSelected(0),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.sunny,
              label: 'Today',
              count: 5,
              isSelected: selectedIndex == 1,
              onTap: () => onItemSelected(1),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.calendar_month,
              label: 'Next 7 Days',
              count: 5,
              isSelected: selectedIndex == 2,
              onTap: () => onItemSelected(2),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.inbox_rounded,
              label: 'Inbox',
              count: 3,
              isSelected: selectedIndex == 3,
              onTap: () => onItemSelected(3),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.article_outlined,
              label: 'Summary',
              isSelected: selectedIndex == 4,
              onTap: () => onItemSelected(4),
            ),

            const SizedBox(height: 32),
            const Text(
              "Lists",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.list,
              label: 'Clearing',
              isSelected: selectedIndex == 5,
              onTap: () => onItemSelected(5),
              color: Colors.blueAccent,
            ),
            
            const Spacer(),
            
            // Logout button could go here
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
  final int? count;
  final Color? color;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
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
              ? GlassTheme.accentColor.withOpacity(0.2) 
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
            if (count != null)
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
