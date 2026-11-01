import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/farm_model.dart';
import 'backend_api_service.dart';

/// Repository for farm boundary storage backed by NestJS + MongoDB backend.
///
/// Uses an in-memory broadcast [StreamController] so that [saveFarm] and
/// [deleteFarm] immediately push updated lists to all active map listeners —
/// no app restart required to see changes on the map.
class FarmRepository {
  static final FarmRepository _instance = FarmRepository._internal();
  factory FarmRepository() => _instance;
  FarmRepository._internal();

  static FarmRepository get instance => _instance;

  BackendApiService get _backend => BackendApiService.instance;

  // Broadcast controller — all streamUserFarms() subscribers share one source.
  final StreamController<List<FarmModel>> _farmsController =
      StreamController<List<FarmModel>>.broadcast();

  List<FarmModel> _cachedFarms = [];
  bool _isFetching = false;

  /// Current cached list of farms
  List<FarmModel> get cachedFarms => List.unmodifiable(_cachedFarms);

  /// Saves or updates a farm boundary document in MongoDB.
  ///
  /// After a successful save, the new farm is immediately inserted into the
  /// in-memory cache and broadcast to all active map listeners so the green
  /// boundary appears without an app restart.
  Future<String> saveFarm(FarmModel farm) async {
    debugPrint('[FarmRepository] Saving farm ${farm.name} for user ${farm.userId}');
    final id = await _backend.saveFarm(farm);
    final assignedId = (id.isNotEmpty) ? id : farm.id;
    // Update cache with the server-assigned ID.
    _cachedFarms.removeWhere((f) => f.id == assignedId || f.id.isEmpty);
    _cachedFarms.insert(0, FarmModel(
      id: assignedId,
      userId: farm.userId,
      name: farm.name,
      boundary: farm.boundary,
      center: farm.center,
      areaSquareMeters: farm.areaSquareMeters,
      cropType: farm.cropType,
      createdAt: farm.createdAt,
      updatedAt: farm.updatedAt,
    ));
    _farmsController.add(List.unmodifiable(_cachedFarms));
    debugPrint('[FarmRepository] Saved farm $assignedId — broadcast sent');
    return assignedId;
  }

  /// Stream of all farms belonging to the authenticated user.
  ///
  /// Emits the cached list immediately on subscription (if available), kicks
  /// off a backend fetch, and then re-emits on every [saveFarm]/[deleteFarm].
  Stream<List<FarmModel>> streamUserFarms(String uid) {
    late StreamController<List<FarmModel>> sc;
    StreamSubscription<List<FarmModel>>? sub;

    sc = StreamController<List<FarmModel>>(
      onListen: () {
        // 1. Push cached data immediately so the map doesn't blank on resume.
        if (_cachedFarms.isNotEmpty) {
          sc.add(List.unmodifiable(_cachedFarms));
        }
        // 2. Forward all future broadcasts from the shared controller.
        sub = _farmsController.stream.listen(
          (list) { if (!sc.isClosed) sc.add(list); },
          onError: (Object e) { if (!sc.isClosed) sc.addError(e); },
        );
        // 3. Fetch fresh data from backend.
        _fetchFarmsFromBackend();
      },
      onCancel: () {
        sub?.cancel();
        sc.close();
      },
    );

    return sc.stream;
  }

  /// Fetches the full farm list from the backend and broadcasts it.
  Future<void> _fetchFarmsFromBackend() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final fresh = await _backend.getFarms();
      _cachedFarms = List<FarmModel>.from(fresh);
      _farmsController.add(List.unmodifiable(_cachedFarms));
      debugPrint('[FarmRepository] Fetched ${_cachedFarms.length} farms from backend');
    } catch (e) {
      debugPrint('[FarmRepository] _fetchFarmsFromBackend error: $e');
    } finally {
      _isFetching = false;
    }
  }

  /// Fetches all farms belonging to the user (one-shot, no stream).
  Future<List<FarmModel>> getUserFarms(String uid) async {
    try {
      return await _backend.getFarms();
    } catch (e) {
      debugPrint('[FarmRepository] getUserFarms error: $e');
      return [];
    }
  }

  /// Fetches a single farm by ID.
  Future<FarmModel?> getFarm(String uid, String farmId) async {
    try {
      final farms = await _backend.getFarms();
      for (final f in farms) {
        if (f.id == farmId) return f;
      }
      return null;
    } catch (e) {
      debugPrint('[FarmRepository] getFarm error: $e');
      return null;
    }
  }

  /// Deletes a farm by ID and immediately broadcasts the updated list.
  Future<void> deleteFarm(String uid, String farmId) async {
    try {
      await _backend.deleteFarm(farmId);
      _cachedFarms.removeWhere((f) => f.id == farmId);
      _farmsController.add(List.unmodifiable(_cachedFarms));
      debugPrint('[FarmRepository] Deleted farm $farmId — broadcast sent');
    } catch (e) {
      debugPrint('[FarmRepository] deleteFarm error: $e');
      rethrow;
    }
  }
}
