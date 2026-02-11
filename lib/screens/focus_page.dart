import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/focus/focus_target_selector.dart';
import '../widgets/focus/focus_stats_panel.dart';
import '../providers/app_providers.dart';
import '../models/task.dart';
import '../models/habit.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  Timer? _timer;
  static const int _pomodoroTime = 25 * 60;
  int _remainingSeconds = _pomodoroTime;
  bool _isRunning = false;
  bool _isStopwatch = false; // Toggle between Pomo and Stopwatch
  
  // Selected Target
  dynamic _selectedTarget; // Task or Habit
  bool _showSelector = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      final startTime = DateTime.now();
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_isStopwatch) {
              _remainingSeconds++;
            } else {
              if (_remainingSeconds > 0) {
                _remainingSeconds--;
              } else {
                _completeSession(startTime);
              }
            }
          });
        }
      });
    }
  }

  void _completeSession(DateTime startTime) {
    _timer?.cancel();
    final duration = _isStopwatch ? _remainingSeconds : _pomodoroTime;
    
    // Save to DB
    String? taskId;
    String? habitId;
    
    if (_selectedTarget is Task) taskId = (_selectedTarget as Task).id;
    if (_selectedTarget is Habit) habitId = (_selectedTarget as Habit).id;

    ref.read(focusSessionSaverProvider)(
      startTime: startTime,
      duration: duration,
      taskId: taskId,
      habitId: habitId,
    );

    setState(() {
      _isRunning = false;
      if (!_isStopwatch) _remainingSeconds = _pomodoroTime;
      // If stopwatch, maybe keep time or reset? Reset for now.
      if (_isStopwatch) _remainingSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Session Completed & Saved!")),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    
    // The Selector Overlay
    final selectorOverlay = _showSelector ? Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {}, // consume taps
          child: FocusTargetSelector(
            currentSelection: _selectedTarget,
            onSelected: (target) {
              setState(() {
                _selectedTarget = target;
                _showSelector = false;
              });
            },
          ),
        ),
      ),
    ) : const SizedBox.shrink();

    final timerContent = Stack(
      children: [
        Column(
          children: [
            // Top Toggle (Pomo / Stopwatch)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleBtn(text: "Pomo", isSelected: !_isStopwatch, onTap: () => setState(() { _isStopwatch = false; _remainingSeconds = _pomodoroTime; })),
                  _ToggleBtn(text: "Stopwatch", isSelected: _isStopwatch, onTap: () => setState(() { _isStopwatch = true; _remainingSeconds = 0; })),
                ],
              ),
            ),
            
            const Spacer(),

            // Timer Circle
            SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                   CircularProgressIndicator(
                    value: _isStopwatch ? 0 : 1.0 - (_remainingSeconds / _pomodoroTime),
                    strokeWidth: 8,
                    color: GlassTheme.accentColor,
                    backgroundColor: Colors.white10,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Target Selector Button
            GestureDetector(
              onTap: () => setState(() => _showSelector = !_showSelector),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(_getTargetIcon(), color: Colors.white70, size: 18),
                     const SizedBox(width: 12),
                     Text(_getTargetName(), style: const TextStyle(color: Colors.white)),
                     const SizedBox(width: 8),
                     const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Start Button
            GestureDetector(
              onTap: _toggleTimer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
                decoration: BoxDecoration(
                  color: GlassTheme.accentColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                     BoxShadow(color: GlassTheme.accentColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Text(
                  _isRunning ? 'Pause' : 'Start',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
        
        // Overlay for selector
        if (_showSelector)
           Positioned.fill(
             child: GestureDetector(
               onTap: () => setState(() => _showSelector = false),
               child: Container(color: Colors.black54),
             ),
           ),
        selectorOverlay,
      ],
    );

    if (isMobile) {
      // Mobile Layout: Tabs? Or Vertical Scroll?
      // Let's use simple vertical scroll for now
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 600, child: timerContent),
            const SizedBox(height: 2000, child: FocusStatsPanel()), // Constrained height for panel inside scroll
          ],
        ),
      );
    }

    // Desktop Layout
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: timerContent,
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.white10),
        const Expanded(
          flex: 2,
          child: FocusStatsPanel(),
        ),
      ],
    );
  }

  String _getTargetName() {
    if (_selectedTarget == null) return "Focus";
    if (_selectedTarget is Task) return (_selectedTarget as Task).title;
    if (_selectedTarget is Habit) return (_selectedTarget as Habit).name;
    return "Focus";
  }

  IconData _getTargetIcon() {
    if (_selectedTarget == null) return Icons.center_focus_strong;
    if (_selectedTarget is Task) return Icons.check_circle_outline;
    return Icons.loop;
  }
}

class _ToggleBtn extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleBtn({required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
