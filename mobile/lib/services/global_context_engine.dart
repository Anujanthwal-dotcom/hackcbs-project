import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/detection_record.dart';
import '../models/farm_model.dart';
import 'auth_service.dart';
import 'language_service.dart';

/// Global Context Engine for KisaanBandhu.
///
/// Maintains a real-time, event-driven snapshot of the application state:
/// - Application & Navigation Context (current screen, route, active tab)
/// - User Context (UID, language, display name)
/// - Farm Context (selected farm, selected field point / detection)
/// - UI & Task Context (active modal, form values, recent actions)
///
/// Dispatches sanitized, compact context snapshots to the AI Agent.
class GlobalContextEngine extends ChangeNotifier {
  static final GlobalContextEngine _instance = GlobalContextEngine._internal();
  factory GlobalContextEngine() => _instance;
  GlobalContextEngine._internal();

  static GlobalContextEngine get instance => _instance;

  // Root Navigator Key for global navigation and dialogs
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ── Navigation State ────────────────────────────────────────────────────────
  String _currentScreen = 'Scan';
  String _currentRoute = '/';
  String? _previousScreen;
  int _activeTabIndex = 0;

  void Function(int index)? _tabSwitchCallback;

  // ── Farm & Domain State ───────────────────────────────────────────────────
  FarmModel? _selectedFarm;
  DetectionRecord? _selectedDetection;

  // ── UI & Task State ───────────────────────────────────────────────────────
  String? _activeModalName;
  final Map<String, dynamic> _currentFormFields = {};
  final List<String> _recentActivity = [];

  // Mascot visibility
  bool _isMascotVisible = true;

  // ── Getters ───────────────────────────────────────────────────────────────
  String get currentScreen => _currentScreen;
  String get currentRoute => _currentRoute;
  String? get previousScreen => _previousScreen;
  int get activeTabIndex => _activeTabIndex;
  FarmModel? get selectedFarm => _selectedFarm;
  DetectionRecord? get selectedDetection => _selectedDetection;
  String? get activeModalName => _activeModalName;
  Map<String, dynamic> get currentFormFields => Map.unmodifiable(_currentFormFields);
  List<String> get recentActivity => List.unmodifiable(_recentActivity);
  bool get isMascotVisible => _isMascotVisible;

  // ── State Mutation Methods ────────────────────────────────────────────────

  /// Register callback to switch bottom nav tab programmatically
  void registerTabSwitchCallback(void Function(int index) callback) {
    _tabSwitchCallback = callback;
  }

  /// Switch to a tab by index (0: Scan, 1: Map, 2: Help Desk, 3: Profile)
  bool switchTab(int index) {
    if (index < 0 || index > 3) return false;
    _activeTabIndex = index;
    switch (index) {
      case 0:
        _currentScreen = 'Scan';
        break;
      case 1:
        _currentScreen = 'Map';
        break;
      case 2:
        _currentScreen = 'Help Desk';
        break;
      case 3:
        _currentScreen = 'Profile';
        break;
    }
    _tabSwitchCallback?.call(index);
    _logActivity('Switched to tab: $_currentScreen');
    notifyListeners();
    return true;
  }

  /// Switch to a screen by name
  bool navigateToScreenName(String screenName) {
    final lower = screenName.toLowerCase().trim();
    if (lower.contains('scan')) {
      return switchTab(0);
    } else if (lower.contains('map') || lower.contains('farm')) {
      return switchTab(1);
    } else if (lower.contains('help') || lower.contains('desk') || lower.contains('expert')) {
      return switchTab(2);
    } else if (lower.contains('profile') || lower.contains('setting')) {
      return switchTab(3);
    }
    return false;
  }

  /// Update current screen context (e.g. from route change or tab change)
  void setScreen(String screenName, {String? route}) {
    if (_currentScreen == screenName && (route == null || _currentRoute == route)) {
      return;
    }
    _previousScreen = _currentScreen;
    _currentScreen = screenName;
    if (route != null) _currentRoute = route;
    _logActivity('Navigated to: $screenName');
    notifyListeners();
  }

  /// Update selected farm context
  void setSelectedFarm(FarmModel? farm) {
    _selectedFarm = farm;
    if (farm != null) {
      _logActivity('Selected farm: ${farm.name}');
    }
    notifyListeners();
  }

  /// Update selected field point / detection context
  void setSelectedDetection(DetectionRecord? detection) {
    _selectedDetection = detection;
    if (detection != null) {
      _logActivity('Selected detection point: ${detection.displayTitle}');
    }
    notifyListeners();
  }

  /// Track opened dialog or modal
  void setModalState(String? modalName) {
    _activeModalName = modalName;
    if (modalName != null) {
      _logActivity('Opened modal: $modalName');
    }
    notifyListeners();
  }

  /// Update form field values
  void updateFormField(String key, dynamic value) {
    _currentFormFields[key] = value;
    notifyListeners();
  }

  /// Clear form fields
  void clearFormFields() {
    _currentFormFields.clear();
    notifyListeners();
  }

  /// Set mascot visibility
  void setMascotVisible(bool visible) {
    if (_isMascotVisible != visible) {
      _isMascotVisible = visible;
      notifyListeners();
    }
  }

  /// Log meaningful user/app activity
  void _logActivity(String activity) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _recentActivity.insert(0, '[$timestamp] $activity');
    if (_recentActivity.length > 8) {
      _recentActivity.removeLast();
    }
  }

  void trackAction(String action) {
    _logActivity(action);
    notifyListeners();
  }

  // ── Context Snapshot Generation ───────────────────────────────────────────

  /// Generates a compact, privacy-safe context snapshot for the AI agent
  Map<String, dynamic> getSnapshot() {
    final user = AuthService.instance.currentUser;
    final isHindi = LanguageService.instance.isHindi;

    return {
      'application': {
        'currentScreen': _currentScreen,
        'currentRoute': _currentRoute,
        'previousScreen': _previousScreen,
        'activeTabIndex': _activeTabIndex,
        'activeModal': _activeModalName,
      },
      'user': {
        'isAuthenticated': AuthService.instance.isAuthenticated,
        'userId': user?.uid,
        'name': user?.displayName ?? (isHindi ? 'किसान' : 'Farmer'),
        'language': isHindi ? 'hi' : 'en',
      },
      'farm': _selectedFarm != null
          ? {
              'id': _selectedFarm!.id,
              'name': _selectedFarm!.name,
              'cropType': _selectedFarm!.cropType,
              'areaSquareMeters': _selectedFarm!.areaSquareMeters,
              'formattedArea': _selectedFarm!.formattedArea,
              'center': {
                'latitude': _selectedFarm!.center.latitude,
                'longitude': _selectedFarm!.center.longitude,
              },
            }
          : null,
      'detection': _selectedDetection != null
          ? {
              'id': _selectedDetection!.id,
              'crop': _selectedDetection!.crop,
              'condition': _selectedDetection!.condition,
              'confidence': _selectedDetection!.confidencePercentage,
              'severity': _selectedDetection!.latestSeverity ?? 'unknown',
              'displayTitle': _selectedDetection!.displayTitle,
            }
          : null,
      'ui': {
        'formFields': _currentFormFields.isNotEmpty ? _currentFormFields : null,
      },
      'recentActivity': _recentActivity.take(5).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String getSnapshotJson() => jsonEncode(getSnapshot());
}

/// Navigation observer that keeps [GlobalContextEngine] in sync with route transitions
class AgentNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _extractAndSetScreen(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _extractAndSetScreen(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _extractAndSetScreen(newRoute);
    }
  }

  void _extractAndSetScreen(Route<dynamic> route) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    String screenName = 'App';

    if (routeName.contains('FieldAssistant')) {
      screenName = 'Field Point Assistant';
    } else if (routeName.contains('DetectionHistory')) {
      screenName = 'Detection History';
    } else if (routeName.contains('Login')) {
      screenName = 'Login';
    } else if (routeName.contains('AssistantScreen')) {
      screenName = 'Offline AI Assistant';
    } else {
      // In MainNavigationScreen, active tab controls screenName
      final tab = GlobalContextEngine.instance.activeTabIndex;
      switch (tab) {
        case 0:
          screenName = 'Scan';
          break;
        case 1:
          screenName = 'Map';
          break;
        case 2:
          screenName = 'Help Desk';
          break;
        case 3:
          screenName = 'Profile';
          break;
      }
    }

    GlobalContextEngine.instance.setScreen(screenName, route: routeName);
  }
}
