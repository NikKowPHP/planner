import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskContextMenu extends StatelessWidget {
  // This widget is actually a helper to generate PopupMenuItems
  const TaskContextMenu({super.key});

  static List<PopupMenuEntry<String>> buildItems({
    required BuildContext context,
    required Task task,
    required Function(DateTime?) onDateSelect,
    required Function(int) onPrioritySelect,
    required VoidCallback onPin,
    required VoidCallback onDuplicate,
    required VoidCallback onMove,
    required VoidCallback onTags,
    required VoidCallback onDelete,
  }) {
    // final theme = Theme.of(context);
    // final textStyle = TextStyle(color: Colors.white, fontSize: 14);

    return [
      // 1. Header Row: Date & Priority
      PopupMenuItem<String>(
        enabled: false, // Not clickable as a whole, buttons inside are
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Date", style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconButton(
                  icon: Icons.wb_sunny_outlined,
                  tooltip: 'Today',
                  onTap: () {
                    Navigator.pop(context);
                    onDateSelect(DateTime.now());
                  },
                ),
                _IconButton(
                  icon: Icons.wb_twilight,
                  tooltip: 'Tomorrow',
                  onTap: () {
                    Navigator.pop(context);
                    onDateSelect(DateTime.now().add(const Duration(days: 1)));
                  },
                ),
                _IconButton(
                  icon: Icons.calendar_view_week,
                  tooltip: 'Next Week',
                  onTap: () {
                    Navigator.pop(context);
                    onDateSelect(DateTime.now().add(const Duration(days: 7)));
                  },
                ),
                _IconButton(
                  icon: Icons.calendar_month,
                  tooltip: 'Pick Date',
                  onTap: () async {
                    Navigator.pop(context);
                    // Trigger picker in parent
                    onDateSelect(null); 
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text("Priority", style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PriorityButton(
                  color: Colors.redAccent, 
                  isSelected: task.priority == 3,
                  onTap: () { Navigator.pop(context); onPrioritySelect(3); }
                ),
                _PriorityButton(
                  color: Colors.orangeAccent, 
                  isSelected: task.priority == 2,
                   onTap: () { Navigator.pop(context); onPrioritySelect(2); }
                ),
                _PriorityButton(
                  color: Colors.blueAccent, 
                  isSelected: task.priority == 1,
                   onTap: () { Navigator.pop(context); onPrioritySelect(1); }
                ),
                _PriorityButton(
                  color: Colors.grey, 
                  isSelected: task.priority == 0,
                  icon: Icons.flag_outlined,
                   onTap: () { Navigator.pop(context); onPrioritySelect(0); }
                ),
              ],
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      
      // 2. Actions List
      _buildMenuItem(context, 'Add Subtask', Icons.checklist, () {}), // Placeholder
      _buildMenuItem(context, task.isPinned ? 'Unpin' : 'Pin', Icons.push_pin_outlined, onPin),
      _buildMenuItem(context, 'Won\'t Do', Icons.block, () {}), // Placeholder
      
      _buildMenuItem(context, 'Move to', Icons.drive_file_move_outlined, onMove, showArrow: true),
      _buildMenuItem(context, 'Tags', Icons.label_outline, onTags, showArrow: true),
      
      const PopupMenuDivider(),
      
      _buildMenuItem(context, 'Duplicate', Icons.copy, onDuplicate),
      _buildMenuItem(context, 'Copy Link', Icons.link, () {}), // Placeholder
      
      const PopupMenuDivider(),
      
      _buildMenuItem(context, 'Delete', Icons.delete_outline, onDelete, isDestructive: true),
    ];
  }

  static PopupMenuItem<String> _buildMenuItem(
    BuildContext context, 
    String title, 
    IconData icon, 
    VoidCallback onTap, {
    bool isDestructive = false,
    bool showArrow = false,
  }) {
    return PopupMenuItem<String>(
      onTap: onTap,
      height: 40,
      child: Row(
        children: [
          Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title, 
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontSize: 14,
              )
            ),
          ),
          if (showArrow)
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PriorityButton({required this.color, required this.isSelected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          border: isSelected ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        ),
        child: Icon(
          icon ?? Icons.flag, 
          color: isSelected ? color : color.withValues(alpha: 0.7), 
          size: 20
        ),
      ),
    );
  }
}
