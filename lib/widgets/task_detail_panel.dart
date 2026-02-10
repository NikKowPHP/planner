import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task.dart';
import '../theme/glass_theme.dart';

class TaskDetailPanel extends StatefulWidget {
  final Task task;
  final Function(Task) onUpdate;
  final Function(Task) onDelete;
  final VoidCallback onClose;

  const TaskDetailPanel({
    super.key,
    required this.task,
    required this.onUpdate,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<TaskDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupControllers();
  }

  void _setupControllers() {
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description ?? '');
  }

  @override
  void didUpdateWidget(TaskDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _setupControllers();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _handleUpdate({String? title, String? description, int? priority, bool? isCompleted, DateTime? dueDate}) {
    final updatedTask = Task(
      id: widget.task.id,
      userId: widget.task.userId,
      listId: widget.task.listId,
      title: title ?? widget.task.title,
      description: description ?? widget.task.description,
      dueDate: dueDate ?? widget.task.dueDate,
      priority: priority ?? widget.task.priority,
      isCompleted: isCompleted ?? widget.task.isCompleted,
    );
    widget.onUpdate(updatedTask);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.task.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: GlassTheme.accentColor,
            surface: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _handleUpdate(dueDate: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      color: const Color(0xFF161616), // Slightly lighter than background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(
                  value: widget.task.isCompleted,
                  activeColor: GlassTheme.accentColor,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (val) => _handleUpdate(isCompleted: val),
                ),
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.calendar_today,
                  text: _formatDate(widget.task.dueDate),
                  onTap: _pickDate,
                  isActive: widget.task.dueDate != null,
                ),
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.flag,
                  color: _getPriorityColor(widget.task.priority),
                  onTap: () => _handleUpdate(
                    priority: (widget.task.priority + 1) % 4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Task Title',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => _handleUpdate(title: val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    focusNode: _descFocus,
                    maxLines: null,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    decoration: const InputDecoration(
                      hintText: 'Description',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.notes, color: Colors.white30, size: 20),
                      prefixIconConstraints: BoxConstraints(minWidth: 30),
                    ),
                    onChanged: (val) => _handleUpdate(description: val),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Text('Inbox', style: TextStyle(color: Colors.white54)),
                const Spacer(),
                Text(
                  'Created ${_formatDate(DateTime.now())}', // Mock date
                  style: const TextStyle(color: Colors.white24, fontSize: 12),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  onPressed: () => widget.onDelete(widget.task),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutQuint);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date';
    return '${date.day}/${date.month}';
  }

  Color? _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 1: return Colors.blueAccent;
      default: return null;
    }
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String? text;
  final VoidCallback onTap;
  final Color? color;
  final bool isActive;

  const _HeaderButton({
    required this.icon,
    this.text,
    required this.onTap,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? GlassTheme.accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? (isActive ? GlassTheme.accentColor : Colors.white54),
            ),
            if (text != null) ...[
              const SizedBox(width: 6),
              Text(
                text!,
                style: TextStyle(
                  color: isActive ? GlassTheme.accentColor : Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
