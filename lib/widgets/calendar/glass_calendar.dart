import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../theme/glass_theme.dart';
import '../../providers/app_providers.dart';
import '../glass_card.dart';

class GlassCalendar extends ConsumerStatefulWidget {
  final Function(Task) onTaskTap;

  const GlassCalendar({super.key, required this.onTaskTap});

  @override
  ConsumerState<GlassCalendar> createState() => _GlassCalendarState();
}

class _GlassCalendarState extends ConsumerState<GlassCalendar> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final tasksMap = ref.watch(calendarTasksProvider);

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TableCalendar<Task>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                
                // Layout settings to look like a full grid
                shouldFillViewport: true,
                rowHeight: 120, // Taller rows for tasks
                daysOfWeekHeight: 40,

                headerVisible: false, // Using custom header

                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  weekendStyle: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) =>
                      _buildCell(context, day, tasksMap, isToday: false),
                  todayBuilder: (context, day, focusedDay) =>
                      _buildCell(context, day, tasksMap, isToday: true),
                  outsideBuilder: (context, day, focusedDay) =>
                      _buildCell(context, day, tasksMap, isOutside: true),
                  selectedBuilder: (context, day, focusedDay) => _buildCell(
                    context,
                    day,
                    tasksMap,
                    isToday: isSameDay(day, DateTime.now()),
                  ),
                ),
                
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
              ),
            ),
          ],
        ),
        
        // Floating Bottom Bar (View Switcher)
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Center(
            child: GlassCard(
              height: 50,
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              borderRadius: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ViewSwitchButton(text: 'Year', isSelected: false),
                  _ViewSwitchButton(
                    text: 'Month',
                    isSelected: _calendarFormat == CalendarFormat.month,
                    onTap: () =>
                        setState(() => _calendarFormat = CalendarFormat.month),
                  ),
                  _ViewSwitchButton(
                    text: 'Week',
                    isSelected: _calendarFormat == CalendarFormat.week,
                    onTap: () =>
                        setState(() => _calendarFormat = CalendarFormat.week),
                  ),
                  _ViewSwitchButton(text: 'Day', isSelected: false),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    );
                  });
                },
              ),
              TextButton(
                onPressed: () => setState(() => _focusedDay = DateTime.now()),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    Map<DateTime, List<Task>> tasksMap, {
    bool isToday = false,
    bool isOutside = false,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    final tasks = tasksMap[normalized] ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        color: isOutside
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.01),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Number Highlight
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isToday ? GlassTheme.accentColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : (isOutside ? Colors.white24 : Colors.white70),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tasks List
          Expanded(
            child: ListView.builder(
              physics:
                  const NeverScrollableScrollPhysics(), // Provide interaction in details view instead
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                // Show max 4 tasks per cell to avoid clutter
                if (index > 3) return const SizedBox.shrink();
                if (index == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${tasks.length - 3} more',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return _CalendarTaskItem(
                  task: tasks[index],
                  onTap: widget.onTaskTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTaskItem extends StatelessWidget {
  final Task task;
  final Function(Task) onTap;

  const _CalendarTaskItem({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getTaskColor(task);
    
    return GestureDetector(
      onTap: () => onTap(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            // Tiny checkbox visual
            if (!task.isCompleted)
              Container(
                margin: const EdgeInsets.only(right: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.dueDate != null)
              Text(
                DateFormat('HH:mm').format(task.dueDate!),
                style: const TextStyle(color: Colors.white38, fontSize: 8),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(Task task) {
    if (task.isCompleted) return Colors.grey;
    switch (task.priority) {
      case 3:
        return const Color(0xFFFF6B6B); // Red
      case 2:
        return const Color(0xFFFECA57); // Yellow
      case 1:
        return const Color(0xFF48DBFB); // Blue
      default:
        // Generate a deterministic pastel color based on hash if no priority
        final colors = [
          const Color(0xFF10AC84), // Teal
          const Color(0xFF5F27CD), // Purple
          const Color(0xFFFF9F43), // Orange
          const Color(0xFF54A0FF), // Blue
        ];
        return colors[task.title.hashCode % colors.length];
    }
  }
}

class _ViewSwitchButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ViewSwitchButton({
    required this.text,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
