import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../services/logger.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FileLogger _logger = FileLogger();

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _logger.log('Signing up user: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      await _logger.log('Sign up successful for: $email');
      return response;
    } catch (e, stack) {
      await _logger.error('Error signing up user: $email', e, stack);
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _logger.log('Signing in user: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _logger.log('Sign in successful for: $email');
      return response;
    } catch (e, stack) {
      await _logger.error('Error signing in user: $email', e, stack);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final email = currentUser?.email;
      await _logger.log('Signing out user: $email');
      await _supabase.auth.signOut();
      await _logger.log('Sign out successful for: $email');
    } catch (e, stack) {
      await _logger.error('Error signing out', e, stack);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _logger.log('Requesting password reset for: $email');
      await _supabase.auth.resetPasswordForEmail(email);
      await _logger.log('Password reset requested for: $email');
    } catch (e, stack) {
      await _logger.error(
        'Error requesting password reset for: $email',
        e,
        stack,
      );
      rethrow;
    }
  }

  // Update password
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      await _logger.log('Updating password');
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      await _logger.log('Password updated');
      return response;
    } catch (e, stack) {
      await _logger.error('Error updating password', e, stack);
      rethrow;
    }
  }

  // Get current user profile
  Future<UserProfile?> getCurrentProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      await _logger.log('Fetching profile for user: ${user.id}');
      
      // Timeout and Retry logic for network resilience
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 10)); // Prevent infinite hang

      final profile = UserProfile.fromJson(data);
      await _logger.log('Fetched profile for user: ${user.id}');
      return profile;
    } catch (e, stack) {
      await _logger.error('Error fetching profile (Network/Timeout)', e, stack);
      return null;
    }
  }
}
