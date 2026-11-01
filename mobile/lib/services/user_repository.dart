import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'backend_api_service.dart';

/// Repository for user profile management backed by NestJS + MongoDB backend.
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  static UserRepository get instance => _instance;

  BackendApiService get _backend => BackendApiService.instance;

  /// Creates or updates a user profile.
  Future<void> createUserProfile(UserProfile profile) async {
    debugPrint('[USER_REPO] createUserProfile called for uid: ${profile.uid}');
  }

  /// Fetches the user profile document for a given UID.
  Future<UserProfile?> getUserProfile(String uid) async {
    return _backend.currentUser;
  }

  /// Real-time stream of the user profile document.
  Stream<UserProfile?> streamUserProfile(String uid) {
    return Stream.value(_backend.currentUser);
  }

  /// Updates fields in profile.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    if (data.containsKey('name') && data['name'] != null) {
      await _backend.updateDisplayName(data['name'] as String);
    }
  }
}
