import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/glass_theme.dart';
import '../providers/app_providers.dart';
import 'glass_card.dart';

class GlassRail extends StatelessWidget {
  final AppTab activeTab;
  final Function(AppTab) onTabSelected;

  const GlassRail({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            // Logo
            const Icon(Icons.bubble_chart, color: Colors.white, size: 32)
                .animate()
                .scale(duration: 600.ms),
            const SizedBox(height: 32),

            // Navigation Items
            _RailItem(
              icon: Icons.check_circle_outline,
              label: 'Tasks',
              isActive: activeTab == AppTab.tasks,
              onTap: () => onTabSelected(AppTab.tasks),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              isActive: activeTab == AppTab.calendar,
              onTap: () => onTabSelected(AppTab.calendar),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Icons.loop,
              label: 'Habit',
              isActive: activeTab == AppTab.habit,
              onTap: () => onTabSelected(AppTab.habit),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Icons.timer_outlined,
              label: 'Focus',
              isActive: activeTab == AppTab.focus,
              onTap: () => onTabSelected(AppTab.focus),
            ),

            const Spacer(),
            
            // User Avatar / Settings Placeholder
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? GlassTheme.accentColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive 
              ? Border.all(color: GlassTheme.accentColor.withValues(alpha: 0.5))
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? GlassTheme.accentColor : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
