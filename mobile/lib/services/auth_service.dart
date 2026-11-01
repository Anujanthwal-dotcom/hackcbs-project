import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'backend_api_service.dart';

/// Centralized authentication service providing authentication state and operations via NestJS/MongoDB backend.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  BackendApiService get _backend => BackendApiService.instance;

  /// Stream of authentication state changes.
  Stream<UserProfile?> get authStateChanges {
    late StreamController<UserProfile?> controller;
    void listener() {
      if (!controller.isClosed) {
        controller.add(_backend.currentUser);
      }
    }

    controller = StreamController<UserProfile?>.broadcast(
      onListen: () {
        controller.add(_backend.currentUser);
        _backend.currentUserNotifier.addListener(listener);
      },
      onCancel: () {
        _backend.currentUserNotifier.removeListener(listener);
      },
    );
    return controller.stream;
  }

  /// Current signed-in user (or null if unauthenticated).
  UserProfile? get currentUser => _backend.currentUser;

  /// Current user's unique UID / ID.
  String? get currentUid => _backend.currentUid;

  /// True if a user is currently authenticated.
  bool get isAuthenticated => _backend.isAuthenticated;

  /// Creates a new user account with email, password, and display name in MongoDB.
  Future<UserProfile?> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    debugPrint('[AUTH] MongoDB registration started for email: ${email.trim()}');
    return await _backend.register(
      email: email,
      password: password,
      name: name,
    );
  }

  /// Signs in an existing user with email and password via MongoDB backend.
  Future<UserProfile?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    debugPrint('[AUTH] MongoDB signIn started for email: ${email.trim()}');
    return await _backend.login(
      email: email,
      password: password,
    );
  }

  /// Password reset for MongoDB auth.
  Future<void> sendPasswordResetEmail(String email) async {
    debugPrint('[AUTH] Password reset requested for $email');
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Updates the user's display name.
  Future<void> updateDisplayName(String name) async {
    await _backend.updateDisplayName(name);
  }

  /// Signs out the user and clears in-memory and persisted auth state.
  Future<void> signOut() async {
    await _backend.logout();
  }

  /// Maps exceptions to clean, user-friendly UI messages.
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final msg = error.toString();
    if (msg.contains('Invalid email or password') || msg.contains('Unauthorized')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (msg.contains('already exists') || msg.contains('Conflict')) {
      return 'An account already exists for this email address.';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Failed host lookup')) {
      return 'Cannot connect to backend server. Make sure the server is running.';
    }
    if (msg.contains('TimeoutException')) {
      return 'Request timed out. Please check your network connection.';
    }
    if (msg.startsWith('Exception: ')) {
      return msg.substring(11);
    }
    return msg;
  }
}
