import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/focus/focus_target_selector.dart';
import '../widgets/focus/focus_stats_panel.dart';
import '../providers/app_providers.dart';
import '../providers/focus_provider.dart';
import '../models/task.dart';
import '../models/habit.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  bool _showSelector = false;

  @override
  Widget build(BuildContext context) {
    final focusAsync = ref.watch(focusProvider);
    final isMobile = ResponsiveLayout.isMobile(context);

    return focusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
      data: (state) {
        // Check for completion
        if (!state.isStopwatch && state.remainingSeconds == 0 && !state.isRunning) {
          // We can show a 'Session Complete' UI or simple snackbar logic handled here
          // But strictly logic: we wait for user to hit "Done" or auto-save.
          // Let's add a "Done" button or auto-reset in _completeSession
        }

        // Resolve Selected Target Object for Display
        dynamic selectedTargetObj;
        if (state.selectedTargetId != null) {
          if (state.targetType == 'task') {
            final tasks = ref.watch(tasksProvider).asData?.value ?? [];
            try {
              selectedTargetObj = tasks.firstWhere((t) => t.id == state.selectedTargetId);
            } catch (_) {}
          } else if (state.targetType == 'habit') {
            final habits = ref.watch(habitsProvider).asData?.value ?? [];
             try {
              selectedTargetObj = habits.firstWhere((h) => h.id == state.selectedTargetId);
            } catch (_) {}
          }
        }

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
                      _ToggleBtn(
                        text: "Pomo", 
                        isSelected: !state.isStopwatch, 
                        onTap: () => ref.read(focusProvider.notifier).setMode(isStopwatch: false)
                      ),
                      _ToggleBtn(
                        text: "Stopwatch", 
                        isSelected: state.isStopwatch, 
                        onTap: () => ref.read(focusProvider.notifier).setMode(isStopwatch: true)
                      ),
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
                        value: state.isStopwatch 
                          ? 0 
                          : (state.initialDuration > 0 ? 1.0 - (state.remainingSeconds / state.initialDuration) : 0),
                        strokeWidth: 8,
                        color: GlassTheme.accentColor,
                        backgroundColor: Colors.white10,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          _formatTime(state.remainingSeconds),
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
                        Icon(_getTargetIcon(selectedTargetObj), color: Colors.white70, size: 18),
                        const SizedBox(width: 12),
                        Text(_getTargetName(selectedTargetObj), style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Actions
                if (state.remainingSeconds == 0 && !state.isStopwatch && !state.isRunning)
                  // Completion State
                  GestureDetector(
                    onTap: () => _handleSessionComplete(state, selectedTargetObj),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Save & Reset',
                        style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       // Reset Button (only if paused and progressed)
                       if (!state.isRunning && (state.isStopwatch ? state.remainingSeconds > 0 : state.remainingSeconds < state.initialDuration))
                         Padding(
                           padding: const EdgeInsets.only(right: 24),
                           child: _ControlButton(
                             icon: Icons.refresh,
                             onTap: () => ref.read(focusProvider.notifier).reset(),
                             color: Colors.white,
                           ),
                         ),

                       // Start/Pause Button
                       GestureDetector(
                        onTap: () => ref.read(focusProvider.notifier).toggleTimer(),
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
                            state.isRunning ? 'Pause' : 'Start',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                       // Finish Button (Stopwatch only)
                       if (state.isStopwatch && !state.isRunning && state.remainingSeconds > 0)
                         Padding(
                           padding: const EdgeInsets.only(left: 24),
                           child: _ControlButton(
                             icon: Icons.stop,
                             onTap: () => _handleSessionComplete(state, selectedTargetObj),
                             color: Colors.redAccent,
                           ),
                         ),
                    ],
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
            
            // Selector Widget
            if (_showSelector)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: FocusTargetSelector(
                    currentSelection: selectedTargetObj,
                    onSelected: (target) {
                      String? id;
                      String? type;
                      if (target is Task) { id = target.id; type = 'task'; }
                      if (target is Habit) { id = target.id; type = 'habit'; }
                      
                      ref.read(focusProvider.notifier).setTarget(id, type);
                      setState(() => _showSelector = false);
                    },
                  ),
                ),
              ),
          ],
        );

        if (isMobile) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 600, child: timerContent),
                const SizedBox(height: 2000, child: FocusStatsPanel()), 
              ],
            ),
          );
        }

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
    );
  }

  Future<void> _handleSessionComplete(FocusState state, dynamic selectedTarget) async {
    try {
      final duration = state.isStopwatch ? state.remainingSeconds : state.initialDuration;
      
      String? taskId;
      String? habitId;
      if (selectedTarget is Task) taskId = selectedTarget.id;
      if (selectedTarget is Habit) habitId = selectedTarget.id;

      await ref.read(focusSessionSaverProvider)(
        startTime: DateTime.now().subtract(Duration(seconds: duration)),
        duration: duration,
        taskId: taskId,
        habitId: habitId,
      );
      
      ref.read(focusProvider.notifier).reset();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session Saved!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save session: $e")),
        );
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getTargetName(dynamic target) {
    if (target == null) return "Focus";
    if (target is Task) return target.title;
    if (target is Habit) return target.name;
    return "Focus";
  }

  IconData _getTargetIcon(dynamic target) {
    if (target == null) return Icons.center_focus_strong;
    if (target is Task) return Icons.check_circle_outline;
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
