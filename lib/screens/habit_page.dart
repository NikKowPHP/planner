import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_providers.dart';
import '../providers/focus_provider.dart';
import '../widgets/glass_card.dart';
import '../theme/glass_theme.dart';
import '../models/habit.dart';
import '../services/logger.dart';
import '../widgets/responsive_layout.dart';

// ─── Shared helper ───────────────────────────────────────────────
int calculateStreak(List<DateTime> logs, DateTime today) {
  if (logs.isEmpty) return 0;
  final sorted = List<DateTime>.from(logs)..sort((a, b) => b.compareTo(a));
  int streak = 0;
  DateTime check = today;
  if (!sorted.any((d) => d.isAtSameMomentAs(today))) {
    check = today.subtract(const Duration(days: 1));
  }
  while (sorted.any((d) => d.isAtSameMomentAs(check))) {
    streak++;
    check = check.subtract(const Duration(days: 1));
  }
  return streak;
}

// ─── Constants ────────────────────────────────────────────────────
const _kDayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// Predefined icons for the picker
const _kHabitIcons = <IconData>[
  Icons.code,
  Icons.fitness_center,
  Icons.menu_book,
  Icons.self_improvement,
  Icons.water_drop,
  Icons.bedtime,
  Icons.directions_run,
  Icons.music_note,
  Icons.brush,
  Icons.restaurant,
  Icons.pets,
  Icons.eco,
];

// Predefined colors for the picker
const _kHabitColors = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFFFF9F43),
  Color(0xFFFECA57),
  Color(0xFF48DBFB),
  Color(0xFF0ABDE3),
  Color(0xFF5F27CD),
  Color(0xFFEE5A24),
  Color(0xFF10AC84),
  Color(0xFF01A3A4),
  Color(0xFFC44569),
  Color(0xFF6C5CE7),
  Color(0xFF00CECE),
];

Color _habitColor(Habit habit) {
  if (habit.color != null && habit.color!.isNotEmpty) {
    try {
      return Color(int.parse(habit.color!.replaceAll('#', '0xFF')));
    } catch (_) {}
  }
  return const Color(0xFF48DBFB);
}

IconData _habitIcon(Habit habit) {
  if (habit.icon != null && habit.icon!.isNotEmpty) {
    try {
      final code = int.parse(habit.icon!);
      return IconData(code, fontFamily: 'MaterialIcons');
    } catch (_) {}
  }
  return Icons.check_circle_outline;
}

// ════════════════════════════════════════════════════════════════════
//  HabitPage
// ════════════════════════════════════════════════════════════════════

class HabitPage extends ConsumerStatefulWidget {
  const HabitPage({super.key});

  @override
  ConsumerState<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends ConsumerState<HabitPage> {
  Habit? _selectedHabit;

  void _showHabitContextMenu(Habit habit, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: const Color(0xFF1E1E1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      items: <PopupMenuEntry<String>>[
        _buildPopupItem('edit', 'Edit', Icons.edit_outlined),
        _buildPopupItem('archive', habit.isArchived ? 'Unarchive' : 'Archive', Icons.archive_outlined),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('pomo', 'Start Focus', Icons.track_changes_outlined, hasSubmenu: true),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('delete', 'Delete', Icons.delete_outline, isDestructive: true),
      ],
    ).then((value) {
      if (value == null) return;

      final notifier = ref.read(habitsProvider.notifier);

      switch (value) {
        case 'edit':
          if (mounted) {
            _showEditHabitDialog(context, ref, habit);
          }
          break;
        case 'archive':
          notifier.archiveHabit(habit.id, !habit.isArchived);
          break;
        case 'pomo':
          ref.read(focusProvider.notifier).setTarget(habit.id, 'habit');
          ref.read(homeViewProvider.notifier).setActiveTab(AppTab.focus);
          ref.read(focusProvider.notifier).toggleTimer();
          break;
        case 'delete':
          _confirmDelete(habit);
          break;
      }
    });
  }

  PopupMenuItem<String> _buildPopupItem(
    String value, String title, IconData icon, 
    {bool isDestructive = false, bool hasSubmenu = false}
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDestructive ? Colors.redAccent : Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: TextStyle(
              color: isDestructive ? Colors.redAccent : Colors.white, 
              fontSize: 14
            ))
          ),
          if (hasSubmenu) 
            const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
        ],
      ),
    );
  }

  void _confirmDelete(Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Delete Habit?"),
        content: Text("Are you sure you want to delete '${habit.name}'? This will also remove all historical logs."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(habitLogsProvider);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Sync local selection with global selection from search
    final globalSelectedHabit = ref.watch(homeViewProvider.select((s) => s.selectedHabit));
    if (globalSelectedHabit != null && _selectedHabit?.id != globalSelectedHabit.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedHabit = globalSelectedHabit);
      });
    }

    // Mobile: Show detail panel as full screen if selected
    if (isMobile && _selectedHabit != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _selectedHabit = null);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Custom back button header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _selectedHabit = null),
                  ),
                  const Text(
                    "Habit Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _HabitDetailPanel(
                  habit: _selectedHabit!,
                  logs: logsAsync.value?[_selectedHabit!.id] ?? [],
                  onClose: () => setState(() => _selectedHabit = null),
                  onDelete: () {
                    ref
                        .read(habitsProvider.notifier)
                        .deleteHabit(_selectedHabit!.id);
                    setState(() => _selectedHabit = null);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listContent = Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Habits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _showAddHabitDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DateHeaderBar(today: normalizedToday),
          // Date label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.event_note, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d').format(today),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          Expanded(
            child: habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return const Center(
                    child: Text(
                      "No habits",
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: isMobile ? 100 : 0),
                  itemCount: habits.length,
                  itemBuilder: (context, index) {
                    final habit = habits[index];
                    final logs = logsAsync.value?[habit.id] ?? [];
                    return _HabitItem(
                      habit: habit,
                      logs: logs,
                      today: normalizedToday,
                      isSelected: _selectedHabit?.id == habit.id,
                      onTap: () => setState(() => _selectedHabit = habit),
                      onContextMenu: (pos) => _showHabitContextMenu(habit, pos),
                      onToggle: () async {
                        FileLogger().log('GESTURE: Habit check-in toggled for "${habit.name}"');
                        try {
                          await ref.read(habitToggleProvider)(
                            habit.id,
                            normalizedToday,
                          );
                        } catch (e) {
                          ref
                              .read(loggerProvider)
                              .error(
                                'Habit Toggle Error',
                                e,
                                StackTrace.current,
                              );
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error: $e'),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return listContent;
    }

    return Row(
      children: [
        Expanded(flex: 3, child: listContent),
        if (_selectedHabit != null) ...[
          const VerticalDivider(width: 1, color: Colors.white10),
          Expanded(
            flex: 2,
            child: _HabitDetailPanel(
              habit: _selectedHabit!,
              logs: logsAsync.value?[_selectedHabit!.id] ?? [],
              onClose: () => setState(() => _selectedHabit = null),
              onDelete: () {
                ref
                    .read(habitsProvider.notifier)
                    .deleteHabit(_selectedHabit!.id);
                setState(() => _selectedHabit = null);
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────

  Future<void> _showAddHabitDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    int selectedIconIndex = 0;
    int selectedColorIndex = _kHabitColors.length ~/ 2; // default beige (dark-yellow)
    int goalValue = 1;
    TimeOfDay? selectedTime; // New: for reminder

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('New Habit', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Habit Name',
                    hintStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: GlassTheme.accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon picker
                const Text(
                  'Icon',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kHabitIcons.length, (i) {
                    final selected = i == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? _kHabitColors[selectedColorIndex].withValues(
                                  alpha: 0.3,
                                )
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? _kHabitColors[selectedColorIndex]
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _kHabitIcons[i],
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Color picker
                const Text(
                  'Color',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kHabitColors.length, (i) {
                    final selected = i == selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kHabitColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: selected ? 2.5 : 0,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Goal value
                const Text(
                  'Daily Goal',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white54,
                      ),
                      onPressed: goalValue > 1
                          ? () => setDialogState(() => goalValue--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$goalValue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white54,
                      ),
                      onPressed: () => setDialogState(() => goalValue++),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'times / day',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                
                // Reminder Section
                const SizedBox(height: 20),
                const Text('Daily Reminder', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: GlassTheme.accentColor, surface: Color(0xFF1E1E1E))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime != null ? selectedTime!.format(context) : 'No Reminder',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final logger = FileLogger();
                if (nameController.text.trim().isNotEmpty) {
                  await logger.log(
                    'HABIT_UI: Requesting new habit: ${nameController.text}',
                  );
                  try {
                    final c = _kHabitColors[selectedColorIndex];
                    final colorHex =
                        '#${c.toARGB32().toRadixString(16).substring(2)}';
                    final iconCode = _kHabitIcons[selectedIconIndex].codePoint
                        .toString();
                    
                    // Format "HH:mm"
                    String? reminderStr;
                    if (selectedTime != null) {
                      final h = selectedTime!.hour.toString().padLeft(2, '0');
                      final m = selectedTime!.minute.toString().padLeft(2, '0');
                      reminderStr = "$h:$m";
                    }
                    
                    await ref
                        .read(habitsProvider.notifier)
                        .createHabit(
                          nameController.text.trim(),
                          icon: iconCode,
                          color: colorHex,
                          reminderTime: reminderStr,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e, s) {
                    await logger.error(
                      'HABIT_UI: Error during habit dialog submission',
                      e,
                      s,
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditHabitDialog(BuildContext context, WidgetRef ref, Habit habit) async {
    final nameController = TextEditingController(text: habit.name);
    int selectedIconIndex = _kHabitIcons.indexWhere((icon) => icon.codePoint.toString() == habit.icon);
    if (selectedIconIndex == -1) selectedIconIndex = 0;
    
    int selectedColorIndex = _kHabitColors.indexWhere((color) => 
      '#${color.toARGB32().toRadixString(16).substring(2)}' == habit.color);
    if (selectedColorIndex == -1) selectedColorIndex = _kHabitColors.length ~/ 2;
    
    int goalValue = habit.goalValue;
    TimeOfDay? selectedTime;
    if (habit.reminderTime != null) {
      final parts = habit.reminderTime!.split(':');
      selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Edit Habit', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Habit Name',
                    hintStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: GlassTheme.accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon picker
                const Text(
                  'Icon',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kHabitIcons.length, (i) {
                    final selected = i == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? _kHabitColors[selectedColorIndex].withValues(
                                  alpha: 0.3,
                                )
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? _kHabitColors[selectedColorIndex]
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _kHabitIcons[i],
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Color picker
                const Text(
                  'Color',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kHabitColors.length, (i) {
                    final selected = i == selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kHabitColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: selected ? 2.5 : 0,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Goal value
                const Text(
                  'Daily Goal',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white54,
                      ),
                      onPressed: goalValue > 1
                          ? () => setDialogState(() => goalValue--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$goalValue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white54,
                      ),
                      onPressed: () => setDialogState(() => goalValue++),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'times / day',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                
                // Reminder Section
                const SizedBox(height: 20),
                const Text('Daily Reminder', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: GlassTheme.accentColor, surface: Color(0xFF1E1E1E))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime != null ? selectedTime!.format(context) : 'No Reminder',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final logger = FileLogger();
                if (nameController.text.trim().isNotEmpty) {
                  await logger.log(
                    'HABIT_UI: Requesting edit habit: ${nameController.text}',
                  );
                  try {
                    final c = _kHabitColors[selectedColorIndex];
                    final colorHex =
                        '#${c.toARGB32().toRadixString(16).substring(2)}';
                    final iconCode = _kHabitIcons[selectedIconIndex].codePoint
                        .toString();
                    
                    // Format "HH:mm"
                    String? reminderStr;
                    if (selectedTime != null) {
                      final h = selectedTime!.hour.toString().padLeft(2, '0');
                      final m = selectedTime!.minute.toString().padLeft(2, '0');
                      reminderStr = "$h:$m";
                    }
                    
                    await ref
                        .read(habitsProvider.notifier)
                        .updateHabit(
                          habit.id,
                          name: nameController.text.trim(),
                          icon: iconCode,
                          color: colorHex,
                          goalValue: goalValue,
                          reminderTime: reminderStr,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e, s) {
                    await logger.error(
                      'HABIT_UI: Error during habit edit dialog submission',
                      e,
                      s,
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Date Header Bar
// ════════════════════════════════════════════════════════════════════

class _DateHeaderBar extends StatelessWidget {
  final DateTime today;
  const _DateHeaderBar({required this.today});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      children: days.map((d) {
        final isToday = d.isAtSameMomentAs(today);
        final dayLabel = _kDayAbbr[d.weekday - 1]; // 1=Mon ... 7=Sun

        return Expanded(
          child: Column(
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? GlassTheme.accentColor : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Habit List Item
// ════════════════════════════════════════════════════════════════════

class _HabitItem extends StatelessWidget {
  final Habit habit;
  final List<DateTime> logs;
  final DateTime today;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final Function(Offset) onContextMenu;

  const _HabitItem({
    required this.habit,
    required this.logs,
    required this.today,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final streak = calculateStreak(logs, today);
    final totalDays = logs.length;
    final completedToday = logs.any((d) => d.isAtSameMomentAs(today));
    final color = _habitColor(habit);
    final icon = _habitIcon(habit);

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) {
        onContextMenu(details.globalPosition);
      },
      onLongPressStart: (details) {
        onContextMenu(details.globalPosition);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? GlassTheme.accentColor.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? GlassTheme.accentColor.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // ── Colored icon ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),

            // ── Name + stats ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Total days
                      const Icon(Icons.tag, color: Colors.white30, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '$totalDays Days',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Streak
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Text(
                        '$streak Day',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Today checkmark ──
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completedToday
                      ? GlassTheme.accentColor
                      : Colors.transparent,
                  border: Border.all(
                    color: completedToday
                        ? GlassTheme.accentColor
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: completedToday
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Detail Panel
// ════════════════════════════════════════════════════════════════════

class _HabitDetailPanel extends StatefulWidget {
  final Habit habit;
  final List<DateTime> logs;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const _HabitDetailPanel({
    required this.habit,
    required this.logs,
    required this.onClose,
    required this.onDelete,
  });

  @override
  State<_HabitDetailPanel> createState() => _HabitDetailPanelState();
}

class _HabitDetailPanelState extends State<_HabitDetailPanel> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final color = _habitColor(widget.habit);
    final icon = _habitIcon(widget.habit);

    // ── Stats ──
    final totalCheckIns = widget.logs.length;
    final monthlyCheckIns = widget.logs
        .where(
          (d) => d.month == _focusedMonth.month && d.year == _focusedMonth.year,
        )
        .length;
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final checkInRate = daysInMonth > 0
        ? (monthlyCheckIns / daysInMonth * 100).round()
        : 0;
    final streak = calculateStreak(widget.logs, today);

    return Container(
      color: const Color(0xFF141414),
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: widget.onClose,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  onPressed: () {
                    // Could show edit/delete menu
                    showMenu(
                      context: context,
                      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      items: [
                        PopupMenuItem(
                          onTap: widget.onDelete,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Habit name + icon ──
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.habit.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Stats grid (3 × 2) ──
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          iconColor: Colors.greenAccent,
                          label: 'Monthly check-ins',
                          value: '$monthlyCheckIns',
                          sub: 'Day',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          iconColor: Colors.greenAccent,
                          label: 'Total Check-Ins',
                          value: '$totalCheckIns',
                          sub: 'Days',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.pie_chart,
                          iconColor: Colors.orangeAccent,
                          label: 'Monthly check-in rate',
                          value: '$checkInRate',
                          sub: '%',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department,
                          iconColor: Colors.redAccent,
                          label: 'Current Streak',
                          value: '$streak',
                          sub: 'Day',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bar_chart,
                          iconColor: Colors.blueAccent,
                          label: 'Monthly completion',
                          value: '$monthlyCheckIns',
                          sub: 'Count',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bar_chart,
                          iconColor: Colors.purpleAccent,
                          label: 'Total completion',
                          value: '$totalCheckIns',
                          sub: 'Count',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Calendar header with navigation ──
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month - 1,
                            );
                          });
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_focusedMonth),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Calendar ──
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedMonth,
                      calendarFormat: CalendarFormat.month,
                      headerVisible: false,
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        weekendStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.white),
                        outsideTextStyle: TextStyle(color: Colors.white10),
                        todayDecoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(color: Colors.transparent),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final normalized = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          );
                          final isDone = widget.logs.any(
                            (d) => d.isAtSameMomentAs(normalized),
                          );
                          return Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? color.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: isDone
                                        ? Colors.white
                                        : Colors.white38,
                                    fontWeight: isDone
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final normalized = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          );
                          final isDone = widget.logs.any(
                            (d) => d.isAtSameMomentAs(normalized),
                          );
                          return Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? color.withValues(alpha: 0.4)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isDone
                                      ? color
                                      : GlassTheme.accentColor,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: isDone
                                        ? Colors.white
                                        : GlassTheme.accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Daily Goals bar chart ──
                  const Text(
                    'Daily Goals',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '(Count)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: _DailyGoalsChart(
                      logs: widget.logs,
                      month: _focusedMonth,
                      color: color,
                      goalValue: widget.habit.goalValue,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Stat Card
// ════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value, sub;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $sub',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Daily Goals Bar Chart (CustomPaint – zero deps)
// ════════════════════════════════════════════════════════════════════

class _DailyGoalsChart extends StatelessWidget {
  final List<DateTime> logs;
  final DateTime month;
  final Color color;
  final int goalValue;

  const _DailyGoalsChart({
    required this.logs,
    required this.month,
    required this.color,
    required this.goalValue,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    // Count completions per day of month
    final Map<int, int> dayCount = {};
    for (final d in logs) {
      if (d.year == month.year && d.month == month.month) {
        dayCount[d.day] = (dayCount[d.day] ?? 0) + 1;
      }
    }

    // Find max for Y scale
    final maxVal = dayCount.values.fold(goalValue, max);


    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _BarChartPainter(
        daysInMonth: daysInMonth,
        dayCount: dayCount,
        maxVal: maxVal,
        barColor: color,
        goalValue: goalValue,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final int daysInMonth;
  final Map<int, int> dayCount;
  final int maxVal;
  final Color barColor;
  final int goalValue;

  _BarChartPainter({
    required this.daysInMonth,
    required this.dayCount,
    required this.maxVal,
    required this.barColor,
    required this.goalValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottomPadding = 18.0;
    final topPadding = 8.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final barWidth = (size.width / daysInMonth) * 0.6;
    final gap = (size.width / daysInMonth) * 0.4;
    final totalBarSlot = barWidth + gap;

    final barPaint = Paint()..color = barColor;
    final emptyPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 8,
    );

    // Draw Y-axis labels
    for (int y = 0; y <= maxVal; y++) {
      final yPos = topPadding + chartHeight - (y / maxVal) * chartHeight;
      // Only draw a few labels & lines
      if (y == 0 || y == maxVal || y == (maxVal / 2).round()) {
        // Draw dashed line
        final linePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..strokeWidth = 0.5;
        canvas.drawLine(Offset(0, yPos), Offset(size.width, yPos), linePaint);
      }
    }

    // Draw bars
    for (int day = 1; day <= daysInMonth; day++) {
      final count = dayCount[day] ?? 0;
      final x = (day - 1) * totalBarSlot + gap / 2;
      final barHeight = maxVal > 0 ? (count / maxVal) * chartHeight : 0.0;

      // Empty bar background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topPadding, barWidth, chartHeight),
          const Radius.circular(2),
        ),
        emptyPaint,
      );

      // Filled bar
      if (barHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x,
              topPadding + chartHeight - barHeight,
              barWidth,
              barHeight,
            ),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }

      // Day label (every few days to avoid clutter)
      if (day == 1 || day % 5 == 0 || day == daysInMonth) {
        final tp = TextPainter(
          text: TextSpan(text: '$day', style: textStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(
            x + barWidth / 2 - tp.width / 2,
            size.height - bottomPadding + 4,
        ));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.dayCount != dayCount || old.daysInMonth != daysInMonth;
}
