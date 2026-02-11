import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger.dart';
import 'app_providers.dart';

// State Model
class FocusState {
  final int remainingSeconds;
  final int initialDuration; // For calculating progress
  final bool isRunning;
  final bool isStopwatch;
  final bool isBreak;
  final DateTime? lastUpdated;
  
  // Target Info
  final String? selectedTargetId;
  final String? targetType; // 'task' or 'habit'

  const FocusState({
    required this.remainingSeconds,
    this.initialDuration = 25 * 60,
    this.isRunning = false,
    this.isStopwatch = false,
    this.isBreak = false,
    this.lastUpdated,
    this.selectedTargetId,
    this.targetType,
  });

  FocusState copyWith({
    int? remainingSeconds,
    int? initialDuration,
    bool? isRunning,
    bool? isStopwatch,
    bool? isBreak,
    DateTime? lastUpdated,
    String? selectedTargetId,
    String? targetType,
    bool nullTarget = false,
  }) {
    return FocusState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      initialDuration: initialDuration ?? this.initialDuration,
      isRunning: isRunning ?? this.isRunning,
      isStopwatch: isStopwatch ?? this.isStopwatch,
      isBreak: isBreak ?? this.isBreak,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      selectedTargetId: nullTarget ? null : (selectedTargetId ?? this.selectedTargetId),
      targetType: nullTarget ? null : (targetType ?? this.targetType),
    );
  }

  Map<String, dynamic> toJson() => {
    'remainingSeconds': remainingSeconds,
    'initialDuration': initialDuration,
    'isRunning': isRunning,
    'isStopwatch': isStopwatch,
    'isBreak': isBreak,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'selectedTargetId': selectedTargetId,
    'targetType': targetType,
  };

  factory FocusState.fromJson(Map<String, dynamic> json) {
    return FocusState(
      remainingSeconds: json['remainingSeconds'] ?? 25 * 60,
      initialDuration: json['initialDuration'] ?? 25 * 60,
      isRunning: json['isRunning'] ?? false,
      isStopwatch: json['isStopwatch'] ?? false,
      isBreak: json['isBreak'] ?? false,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
      selectedTargetId: json['selectedTargetId'],
      targetType: json['targetType'],
    );
  }
}

// Notifier
class FocusTimerNotifier extends AsyncNotifier<FocusState> {
  Timer? _ticker;
  static const String _storageKey = 'glassy_focus_state';

  @override
  Future<FocusState> build() async {
    // Load from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    
    if (jsonStr != null) {
      try {
        final savedState = FocusState.fromJson(jsonDecode(jsonStr));
        return _restoreState(savedState);
      } catch (e) {
        FileLogger().error('FocusProvider: Error parsing saved state', e);
      }
    }
    return const FocusState(remainingSeconds: 25 * 60);
  }

  // Restore logic to handle time passed while app was closed
  FocusState _restoreState(FocusState saved) {
    if (!saved.isRunning || saved.lastUpdated == null) {
      return saved.copyWith(isRunning: false); // Ensure paused if data invalid
    }

    final now = DateTime.now();
    final diff = now.difference(saved.lastUpdated!).inSeconds;

    if (saved.isStopwatch) {
      // Add elapsed time
      _startTicker();
      return saved.copyWith(
        remainingSeconds: saved.remainingSeconds + diff,
        lastUpdated: now,
      );
    } else {
      // Subtract elapsed time
      final newRemaining = saved.remainingSeconds - diff;
      if (newRemaining <= 0) {
        // Session finished while closed
        return saved.copyWith(
          remainingSeconds: 0,
          isRunning: false,
          lastUpdated: now,
        );
      } else {
        _startTicker();
        return saved.copyWith(
          remainingSeconds: newRemaining,
          lastUpdated: now,
        );
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    final current = state.value;
    if (current == null || !current.isRunning) return;

    if (current.isStopwatch) {
       state = AsyncData(current.copyWith(
         remainingSeconds: current.remainingSeconds + 1,
         lastUpdated: DateTime.now(),
       ));
    } else {
       if (current.remainingSeconds > 0) {
         state = AsyncData(current.copyWith(
           remainingSeconds: current.remainingSeconds - 1,
           lastUpdated: DateTime.now(),
         ));
       } else {
         // IMPORTANT: Cancel ticker before completing to prevent double-calls
         _ticker?.cancel();
         _complete();
       }
    }
    
    // Ensure we persist the lastUpdated and remainingSeconds
    // The SystemTrayService listener will automatically pick up this 
    // state change and update the tooltip.
    _persist();
  }

  Future<void> _persist() async {
    final current = state.value;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(current.toJson()));
  }

  // --- Public Actions ---

  void toggleTimer() {
    final current = state.value;
    if (current == null) return;

    if (current.isRunning) {
      _ticker?.cancel();
      state = AsyncData(current.copyWith(isRunning: false, lastUpdated: DateTime.now()));
    } else {
      // Ensure we start from a clean state if remaining is 0
      int remaining = current.remainingSeconds;
      if (!current.isStopwatch && remaining <= 0) {
        remaining = current.initialDuration;
      }
      
      _startTicker();
      state = AsyncData(current.copyWith(
        isRunning: true, 
        remainingSeconds: remaining, // Reset if finished
        lastUpdated: DateTime.now()
      ));
    }
    _persist();
  }

  void setMode({required bool isStopwatch}) {
    _ticker?.cancel();
    state = AsyncData(state.value!.copyWith(
      isStopwatch: isStopwatch,
      isRunning: false,
      remainingSeconds: isStopwatch ? 0 : 25 * 60,
      initialDuration: isStopwatch ? 0 : 25 * 60,
    ));
    _persist();
  }

  void setTarget(String? id, String? type) {
    state = AsyncData(state.value!.copyWith(
      selectedTargetId: id,
      targetType: type,
      nullTarget: id == null,
    ));
    _persist();
  }

  // NEW: Method to specifically start a break
  void startBreak({int durationMinutes = 5}) {
    _ticker?.cancel();
    state = AsyncData(state.value!.copyWith(
      isBreak: true,
      isRunning: true,
      remainingSeconds: durationMinutes * 60,
      initialDuration: durationMinutes * 60,
      lastUpdated: DateTime.now(),
    ));
    _startTicker();
    _persist();
  }

  void completeSession() {
    _complete();
  }

  void _complete() async {
    _ticker?.cancel();
    final current = state.value!;
    
    // NEW: Trigger Auto-Save only for Focus sessions (not breaks)
    if (!current.isBreak) {
      final duration = current.isStopwatch ? current.remainingSeconds : current.initialDuration;
      try {
        // Directly use FocusService to avoid circular imports
        final focusService = ref.read(focusServiceProvider);
        await focusService.saveSession(
          startTime: DateTime.now().subtract(Duration(seconds: duration)),
          durationSeconds: duration,
          taskId: current.targetType == 'task' ? current.selectedTargetId : null,
          habitId: current.targetType == 'habit' ? current.selectedTargetId : null,
        );
        // Invalidate history provider to refresh stats
        ref.invalidate(focusHistoryProvider);
        
        // If session was linked to a habit, also toggle the habit log for today automatically
        if (current.targetType == 'habit' && current.selectedTargetId != null) {
          final now = DateTime.now();
          final normalized = DateTime(now.year, now.month, now.day);
          await ref.read(habitToggleProvider)(current.selectedTargetId!, normalized);
        }
      } catch (e) {
        FileLogger().error('FocusProvider: Auto-save failed', e);
      }
    }

    state = AsyncData(current.copyWith(
      isRunning: false,
      remainingSeconds: 0,
    ));
    _persist();
  }

  void reset() {
     _ticker?.cancel();
     final current = state.value!;
     state = AsyncData(current.copyWith(
       isRunning: false,
       isBreak: false,
       remainingSeconds: current.isStopwatch ? 0 : 25 * 60,
     ));
     _persist();
  }
}

final focusProvider = AsyncNotifierProvider<FocusTimerNotifier, FocusState>(FocusTimerNotifier.new);
