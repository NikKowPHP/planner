import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _currentUser;
  bool _isLoading = true;

  AuthProvider() {
    _init();
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  void _init() {
    // Set initial user
    _currentUser = _authService.currentUser;
    _isLoading = false;
    notifyListeners();

    // Listen to auth state changes
    _authService.authStateChanges.listen((AuthState state) {
      _currentUser = state.session?.user;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signUp(email: email, password: password);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signIn(email: email, password: password);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signOut();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _authService.resetPassword(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
