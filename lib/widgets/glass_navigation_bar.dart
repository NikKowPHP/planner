import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import '../providers/app_providers.dart';
import 'glass_card.dart';

class GlassNavigationBar extends StatelessWidget {
  final AppTab currentTab;
  final Function(AppTab) onTabSelected;

  const GlassNavigationBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: GlassCard(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: 35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBarItem(
                icon: Icons.check_circle_outline,
                label: 'Tasks',
                isSelected: currentTab == AppTab.tasks,
                onTap: () => onTabSelected(AppTab.tasks),
              ),
              _NavBarItem(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                isSelected: currentTab == AppTab.calendar,
                onTap: () => onTabSelected(AppTab.calendar),
              ),
              _NavBarItem(
                icon: Icons.loop,
                label: 'Habit',
                isSelected: currentTab == AppTab.habit,
                onTap: () => onTabSelected(AppTab.habit),
              ),
              _NavBarItem(
                icon: Icons.timer_outlined,
                label: 'Focus',
                isSelected: currentTab == AppTab.focus,
                onTap: () => onTabSelected(AppTab.focus),
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
      child: SizedBox(
        width: 60,
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
                    size: 24,
                  ),
                )
                .animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 200.ms,
                ),
          ],
        ),
      ),
    );
  }
}
