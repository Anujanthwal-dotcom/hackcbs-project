import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/field_assessment.dart';
import '../screens/assistant/models/chat_message.dart';
import 'backend_api_service.dart';

/// Repository for structured field assessment history and persistent field point conversation.
/// Backed by NestJS + MongoDB backend.
class FieldAssessmentRepository {
  static final FieldAssessmentRepository _instance =
      FieldAssessmentRepository._internal();
  factory FieldAssessmentRepository() => _instance;
  FieldAssessmentRepository._internal();

  static FieldAssessmentRepository get instance => _instance;

  BackendApiService get _backend => BackendApiService.instance;

  /// Saves a new assessment event to MongoDB backend.
  Future<String> saveAssessment(FieldAssessment assessment) async {
    try {
      await _backend.saveAssessment(assessment);
      debugPrint('[FieldAssessmentRepo] Saved assessment to MongoDB for detection ${assessment.detectionId}');
      return assessment.id;
    } catch (e) {
      debugPrint('[FieldAssessmentRepo] Save error: $e');
      return '';
    }
  }

  /// Streams assessments for a detection point.
  Stream<List<FieldAssessment>> streamAssessments(
      String uid, String detectionId) {
    return const Stream.empty();
  }

  /// One-shot fetch of assessments for a detection point.
  Future<List<FieldAssessment>> fetchAssessments(
      String uid, String detectionId, {int limit = 5}) async {
    return [];
  }

  /// Saves a chat message to the persistent field point conversation in MongoDB backend.
  Future<void> saveChatMessage(
      String uid, String detectionId, ChatMessage message) async {
    try {
      await _backend.saveChatMessage(detectionId, message);
      debugPrint('[FieldAssessmentRepo] Persisted message ${message.id} for point $detectionId in MongoDB');
    } catch (e) {
      debugPrint('[FieldAssessmentRepo] Message save warning: $e');
    }
  }

  /// Fetches persistent chat messages for a detection point from MongoDB backend.
  Future<List<ChatMessage>> fetchChatMessages(
      String uid, String detectionId, {int limit = 60}) async {
    try {
      return await _backend.getChatMessages(detectionId);
    } catch (e) {
      debugPrint('[FieldAssessmentRepo] Fetch chat messages error: $e');
      return [];
    }
  }
}
