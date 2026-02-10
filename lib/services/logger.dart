import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static final FileLogger _instance = FileLogger._internal();

  factory FileLogger() {
    return _instance;
  }

  FileLogger._internal();

  File? _logFile;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/app_logs.txt');
  }

  Future<void> log(String message) async {
    if (_logFile == null) await init();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    print(logMessage); // Also print to console
    try {
      await _logFile?.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    if (_logFile == null) await init();
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] ERROR: $message\nError: $error\nStack: $stackTrace\n';
    print(logMessage); // Also print to console
    try {
      await _logFile?.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      print('Failed to write log: $e');
    }
  }
}
