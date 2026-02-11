import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/glass_card.dart';
import '../theme/glass_theme.dart';
import '../services/logger.dart';
import '../widgets/responsive_layout.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  Timer? _timer;
  static const int _defaultTime = 25 * 60; // 25 minutes
  int _remainingSeconds = _defaultTime;
  bool _isRunning = false;
  int _completedSessions = 0;
  int _totalFocusMinutes = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    try {
      if (_isRunning) {
        _timer?.cancel();
        FileLogger().log(
          'FOCUS_UI: Timer paused manually at ${_formatTime(_remainingSeconds)}',
        );
        setState(() => _isRunning = false);
      } else {
        FileLogger().log('FOCUS_UI: Timer started by user');
        setState(() => _isRunning = true);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingSeconds > 0) {
            setState(() => _remainingSeconds--);
          } else {
            _completeSession();
          }
        });
      }
    } catch (e, s) {
      FileLogger().error('FOCUS_UI: Error toggling timer', e, s);
    }
  }

  void _completeSession() {
    _timer?.cancel();
    FileLogger().log('FOCUS_UI: Session completed successfully');
    setState(() {
      _isRunning = false;
      _remainingSeconds = _defaultTime;
      _completedSessions++;
      _totalFocusMinutes += 25;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Focus Session Completed! Great job!")),
    );
  }

  void _resetTimer() {
    FileLogger().log('FOCUS_UI: Timer reset to default');
     _timer?.cancel();
     setState(() {
       _isRunning = false;
       _remainingSeconds = _defaultTime;
     });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_remainingSeconds / _defaultTime);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Responsive content
    final timerSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pomodoro',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: isMobile ? 250 : 300,
                height: isMobile ? 250 : 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      color: GlassTheme.accentColor,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 48 : 64,
                          fontWeight: FontWeight.w200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRunning || _remainingSeconds != _defaultTime)
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: _ControlButton(
                        icon: Icons.refresh,
                        onTap: _resetTimer,
                        color: Colors.white38,
                      ),
                    ),

                  GestureDetector(
                        onTap: _toggleTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: GlassTheme.accentColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: GlassTheme.accentColor.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            _isRunning ? 'Pause' : 'Start',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .animate(target: _isRunning ? 1 : 0)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(0.95, 0.95),
                      ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final statsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) const SizedBox(height: 48),
        const Text(
          'Overview',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(label: 'Sessions', value: '$_completedSessions'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Minutes',
                value: '$_totalFocusMinutes',
                unit: 'm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Recent History',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          // Fixed height for list on mobile to allow scrolling
          SizedBox(height: 200, child: _buildHistoryList())
        else
          Expanded(child: _buildHistoryList()),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: isMobile
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100), // Space for navbar
              child: Column(children: [timerSection, statsSection]),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: timerSection),
                const SizedBox(width: 24),
                SizedBox(width: 300, child: statsSection),
              ],
            ),
    );
  }

  Widget _buildHistoryList() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        shrinkWrap: true, // Important for mobile nesting
        itemCount: _completedSessions,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: GlassTheme.accentColor,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Session ${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '25 minutes',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _StatCard({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: const TextStyle(color: Colors.white38, fontSize: 14)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
