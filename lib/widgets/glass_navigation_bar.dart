import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: GlassCard(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          borderRadius: 40, // Pill shape
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onItemSelected(0),
              ),
              _NavBarItem(
                icon: Icons.explore_rounded,
                label: 'Explore',
                isSelected: selectedIndex == 1,
                onTap: () => onItemSelected(1),
              ),
              _NavBarItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: selectedIndex == 2,
                onTap: () => onItemSelected(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? GlassTheme.accentColor.withValues(alpha: 0.2) 
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? GlassTheme.accentColor : Colors.white70,
              size: 26,
            ),
          ).animate(target: isSelected ? 1 : 0)
           .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms),
           
          // Label with fade
          if(isSelected)
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(duration: 200.ms).moveY(begin: 5, end: 0)
          else 
            const SizedBox(height: 14), // Spacer to keep alignment
        ],
      ),
    );
  }
}
