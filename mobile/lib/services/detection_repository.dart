import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/detection_record.dart';
import 'backend_api_service.dart';

/// Repository for managing user-scoped detection history using NestJS + MongoDB backend.
/// Provides real-time reactive streaming so newly scanned disease points instantly appear
/// on MapScreen and other views without requiring an app restart.
class DetectionRepository {
  static final DetectionRepository _instance = DetectionRepository._internal();
  factory DetectionRepository() => _instance;
  DetectionRepository._internal();

  static DetectionRepository get instance => _instance;

  BackendApiService get _backend => BackendApiService.instance;

  final StreamController<List<DetectionRecord>> _detectionsController =
      StreamController<List<DetectionRecord>>.broadcast();

  List<DetectionRecord> _cachedDetections = [];
  bool _isFetching = false;

  /// Saves a detection record to MongoDB backend, updates the in-memory cache,
  /// and immediately broadcasts the new detection to all active map listeners.
  Future<String> saveDetection(DetectionRecord record) async {
    debugPrint('[SCAN] DETECTION: saving detection to MongoDB backend for farmId=${record.farmId}');
    try {
      final id = await _backend.saveDetection(record);
      debugPrint('[SCAN] BACKEND: write successful docId=$id');

      final assignedId = id.isNotEmpty
          ? id
          : (record.id.isNotEmpty
              ? record.id
              : 'det_${DateTime.now().millisecondsSinceEpoch}');
      final savedRecord = record.copyWith(id: assignedId);

      // Add new detection to the top of the cache and immediately broadcast
      _cachedDetections.removeWhere((d) => d.id == assignedId);
      _cachedDetections.insert(0, savedRecord);
      _detectionsController.add(List.unmodifiable(_cachedDetections));

      debugPrint(
          '[SCAN] REALTIME: Broadcasted updated detections list (total=${_cachedDetections.length})');
      return assignedId;
    } catch (e, stack) {
      debugPrint('[SCAN] BACKEND: write error: $e\n$stack');
      rethrow;
    }
  }

  /// Streams all detection history for a user, ordered newest first.
  /// Emits the cached detections immediately, then fetches from the backend,
  /// and continuously emits any newly scanned detections in real time.
  Stream<List<DetectionRecord>> streamUserDetections(String uid) {
    debugPrint('[MAP] Subscribing to user detections stream for uid=$uid');

    late StreamController<List<DetectionRecord>> listenerController;
    StreamSubscription? sub;

    listenerController = StreamController<List<DetectionRecord>>(
      onListen: () {
        // 1. Emit currently cached detections right away
        if (_cachedDetections.isNotEmpty) {
          listenerController.add(List.unmodifiable(_cachedDetections));
        }

        // 2. Fetch fresh list from backend
        _fetchDetectionsFromBackend();

        // 3. Listen to realtime additions from scan_screen
        sub = _detectionsController.stream.listen((list) {
          if (!listenerController.isClosed) {
            listenerController.add(list);
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        listenerController.close();
      },
    );

    return listenerController.stream;
  }

  Future<void> _fetchDetectionsFromBackend() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final fresh = await _backend.getDetections();
      if (fresh.isNotEmpty) {
        // Merge fresh detections with any locally added ones
        final existingIds = fresh.map((d) => d.id).toSet();
        final localOnly =
            _cachedDetections.where((d) => !existingIds.contains(d.id));
        _cachedDetections = [...localOnly, ...fresh];
        _detectionsController.add(List.unmodifiable(_cachedDetections));
        debugPrint(
            '[DetectionRepo] Refreshed detections from backend: ${_cachedDetections.length}');
      }
    } catch (e) {
      debugPrint('[DetectionRepo] Fetch detections error: $e');
    } finally {
      _isFetching = false;
    }
  }

  /// Streams detections for a specific farm, filtered by farmId, newest first.
  Stream<List<DetectionRecord>> streamFarmDetections(
      String uid, String farmId) {
    return streamUserDetections(uid).map(
      (list) => list.where((d) => d.farmId == farmId).toList(),
    );
  }

  /// Updates lifecycle/assessment metadata on an existing detection record.
  Future<void> updateDetectionMeta(
    String uid,
    String detectionId, {
    required String latestSeverity,
    required String latestRecommendation,
    required int reviewCount,
    required DateTime lastReviewedAt,
  }) async {
    final idx = _cachedDetections.indexWhere((d) => d.id == detectionId);
    if (idx != -1) {
      final old = _cachedDetections[idx];
      _cachedDetections[idx] = old.copyWith(
        latestSeverity: latestSeverity,
        latestRecommendation: latestRecommendation,
        reviewCount: reviewCount,
        lastReviewedAt: lastReviewedAt,
      );
      _detectionsController.add(List.unmodifiable(_cachedDetections));
    }
    debugPrint('[DetectionRepo] updateDetectionMeta called for $detectionId');
  }

  /// Deletes a specific detection record.
  Future<void> deleteDetection(String uid, String detectionId) async {
    _cachedDetections.removeWhere((d) => d.id == detectionId);
    _detectionsController.add(List.unmodifiable(_cachedDetections));
    debugPrint('[DetectionRepo] deleteDetection called for $detectionId');
  }
}
