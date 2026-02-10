import 'package:flutter/material.dart';
import '../models/custom_filter.dart';
import '../theme/glass_theme.dart';
import 'auth/glass_text_field.dart';

class FilterEditorDialog extends StatefulWidget {
  final CustomFilter? filter; // If null, creating new
  final Function(String name, FilterCriteria criteria) onSave;

  const FilterEditorDialog({super.key, this.filter, required this.onSave});

  @override
  State<FilterEditorDialog> createState() => _FilterEditorDialogState();
}

class _FilterEditorDialogState extends State<FilterEditorDialog> {
  late TextEditingController _nameController;
  
  // Criteria State
  List<int> _selectedPriorities = [];
  String? _selectedDateRange;
  // Note: For MVP we aren't fetching Lists/Tags inside the dialog, 
  // but you can pass them in if needed. Focusing on Priority/Date/State for now.
  bool? _isCompleted = false; // Default to active

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.filter?.name ?? '');
    
    if (widget.filter != null) {
      _selectedPriorities = List.from(widget.filter!.criteria.priorities);
      _selectedDateRange = widget.filter!.criteria.dateRange;
      _isCompleted = widget.filter!.criteria.isCompleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(widget.filter == null ? 'New Smart Filter' : 'Edit Filter', 
          style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              GlassTextField(
                controller: _nameController,
                hintText: 'Filter Name (e.g., Important Work)',
              ),
              const SizedBox(height: 24),

              // Priority Section
              const Text('Priority', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [3, 2, 1, 0].map((p) {
                  final isSelected = _selectedPriorities.contains(p);
                  return FilterChip(
                    label: Text(_priorityLabel(p)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedPriorities.add(p);
                        } else {
                          _selectedPriorities.remove(p);
                        }
                      });
                    },
                    backgroundColor: Colors.white10,
                    selectedColor: _priorityColor(p).withValues(alpha: 0.3),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Date Section
              const Text('Due Date', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDateRange,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: GlassTheme.accentColor)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'no_date', child: Text('No Date')),
                ],
                onChanged: (val) => setState(() => _selectedDateRange = val),
              ),

              const SizedBox(height: 16),
              // Status Section
               const Text('Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                   FilterChip(
                    label: const Text("Active"),
                    selected: _isCompleted == false,
                    onSelected: (v) => setState(() => _isCompleted = false),
                    backgroundColor: Colors.white10,
                    selectedColor: GlassTheme.accentColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text("Completed"),
                    selected: _isCompleted == true,
                    onSelected: (v) => setState(() => _isCompleted = true),
                     backgroundColor: Colors.white10,
                    selectedColor: GlassTheme.accentColor.withValues(alpha: 0.3),
                  ),
                   const SizedBox(width: 8),
                  FilterChip(
                    label: const Text("All"),
                    selected: _isCompleted == null,
                    onSelected: (v) => setState(() => _isCompleted = null),
                     backgroundColor: Colors.white10,
                    selectedColor: GlassTheme.accentColor.withValues(alpha: 0.3),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.accentColor),
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            
            final criteria = FilterCriteria(
              priorities: _selectedPriorities,
              dateRange: _selectedDateRange,
              isCompleted: _isCompleted,
            );
            
            widget.onSave(_nameController.text.trim(), criteria);
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 3: return 'High';
      case 2: return 'Medium';
      case 1: return 'Low';
      default: return 'None';
    }
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 3: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 1: return Colors.blueAccent;
      default: return Colors.white;
    }
  }
}
