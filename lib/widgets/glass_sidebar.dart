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
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: selectedIndex == 0,
              onTap: () => onItemSelected(0),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.explore_rounded,
              label: 'Explore',
              isSelected: selectedIndex == 1,
              onTap: () => onItemSelected(1),
            ),
            const SizedBox(height: 16),
            _SidebarItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isSelected: selectedIndex == 2,
              onTap: () => onItemSelected(2),
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? GlassTheme.accentColor.withOpacity(0.2) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? GlassTheme.accentColor.withOpacity(0.3) 
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? GlassTheme.accentColor : Colors.white70,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
