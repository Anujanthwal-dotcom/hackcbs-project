import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../models/agricultural_place.dart';
import '../../services/help_desk_service.dart';
import '../../services/location_geocoding_service.dart';
import '../../services/location_service.dart';
import '../../widgets/nature_background.dart';
import '../../services/semantic_ui_registry.dart';
import 'widgets/help_desk_card.dart';

enum _HelpDeskState {
  initial,
  locating,
  searching,
  success,
  empty,
  error,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
}

class HelpDeskScreen extends StatefulWidget {
  const HelpDeskScreen({super.key});

  @override
  State<HelpDeskScreen> createState() => _HelpDeskScreenState();
}

class _HelpDeskScreenState extends State<HelpDeskScreen> {
  _HelpDeskState _state = _HelpDeskState.initial;
  String? _errorMessage;
  String? _locationDisplayName;

  int _searchRadiusMeters = 5000;
  String _selectedCategory = 'all';

  List<AgriculturalPlace> _allPlaces = [];
  List<AgriculturalPlace> _filteredPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces({bool forceRefresh = false, int? overrideRadius}) async {
    if (!mounted) return;

    if (overrideRadius != null) {
      _searchRadiusMeters = overrideRadius;
    }

    setState(() {
      _state = _HelpDeskState.locating;
      _errorMessage = null;
    });

    // Step 1: Check & Request Location Permission
    final perm = await LocationService.instance.checkAndRequestPermission();
    if (!mounted) return;

    if (perm.status == LocationPermissionStatus.serviceDisabled) {
      setState(() {
        _state = _HelpDeskState.serviceDisabled;
      });
      return;
    }

    if (perm.status == LocationPermissionStatus.denied) {
      setState(() {
        _state = _HelpDeskState.permissionDenied;
      });
      return;
    }

    if (perm.status == LocationPermissionStatus.permanentlyDenied) {
      setState(() {
        _state = _HelpDeskState.permissionPermanentlyDenied;
      });
      return;
    }

    // Step 2: Acquire current user coordinates once
    final position = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _state = _HelpDeskState.error;
        _errorMessage = 'Unable to determine your current GPS coordinates. Please try again.';
      });
      return;
    }

    setState(() {
      _state = _HelpDeskState.searching;
    });

    // Step 3: Fetch reverse geocoded locality in parallel
    LocationGeocodingService.instance
        .reverseGeocode(position.latitude, position.longitude)
        .then((displayName) {
      if (mounted && displayName != null && displayName.isNotEmpty) {
        setState(() {
          _locationDisplayName = displayName;
        });
      }
    });

    // Step 4: Fetch real agricultural support centers
    try {
      if (forceRefresh) {
        HelpDeskService.instance.clearCache();
      }

      final places = await HelpDeskService.instance.fetchNearbyAgriculturalPlaces(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: _searchRadiusMeters,
      );

      if (!mounted) return;

      _allPlaces = places;
      _applyCategoryFilter();

      setState(() {
        if (_allPlaces.isEmpty) {
          _state = _HelpDeskState.empty;
        } else {
          _state = _HelpDeskState.success;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _HelpDeskState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyCategoryFilter() {
    if (_selectedCategory == 'all') {
      _filteredPlaces = List.from(_allPlaces);
    } else if (_selectedCategory == 'lab') {
      _filteredPlaces = _allPlaces.where((p) => p.category == 'lab').toList();
    } else if (_selectedCategory == 'expert') {
      _filteredPlaces = _allPlaces.where((p) => p.category == 'kvk' || p.category == 'expert').toList();
    } else if (_selectedCategory == 'research') {
      _filteredPlaces = _allPlaces.where((p) => p.category == 'research').toList();
    } else if (_selectedCategory == 'government') {
      _filteredPlaces = _allPlaces.where((p) => p.category == 'government').toList();
    } else if (_selectedCategory == 'disease_help') {
      _filteredPlaces = _allPlaces.where((p) => p.category == 'disease_help' || p.category == 'lab').toList();
    } else {
      _filteredPlaces = List.from(_allPlaces);
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _applyCategoryFilter();
    });
  }

  void _expandSearchRadius() {
    int nextRadius = 15000;
    if (_searchRadiusMeters == 5000) {
      nextRadius = 15000;
    } else if (_searchRadiusMeters == 15000) {
      nextRadius = 30000;
    } else if (_searchRadiusMeters == 30000) {
      nextRadius = 50000;
    } else {
      nextRadius = _searchRadiusMeters + 25000;
    }

    _loadNearbyPlaces(overrideRadius: nextRadius);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.paleCream,
      body: NatureBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n?.helpDeskTitle ?? 'Help Desk',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGreen,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreenHighlight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_searchRadiusMeters ~/ 1000} km',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n?.helpDeskSubtitle ?? 'Find agricultural support near you',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5A7250),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AgentUiElement(
                      id: 'help_desk_refresh',
                      label: 'Refresh Nearby Experts',
                      description: 'Re-queries Google Places API for nearby agricultural centers and experts',
                      screen: 'Help Desk',
                      onTrigger: () => _loadNearbyPlaces(forceRefresh: true),
                      child: IconButton.filledTonal(
                        onPressed: () => _loadNearbyPlaces(forceRefresh: true),
                        icon: const Icon(Icons.refresh, color: AppTheme.darkGreen, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE5ECCF),
                        ),
                        tooltip: l10n?.helpDeskSearchAgain ?? 'Search Again',
                      ),
                    ),
                  ],
                ),
              ),

              // Location Banner (shows locality name, never raw coordinates)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E9D4), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF3F662F)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locationDisplayName != null
                              ? (l10n?.helpDeskSearchingNear(_locationDisplayName!) ??
                                  'Searching near $_locationDisplayName')
                              : (l10n?.helpDeskSearchingCurrent ?? 'Searching near your current location'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3F662F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Category Filter Bar
              _buildCategoryBar(l10n),

              const SizedBox(height: 6),

              // Main Content Area based on State
              Expanded(
                child: _buildBody(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(AppLocalizations? l10n) {
    final categories = [
      {'key': 'all', 'label': l10n?.categoryAll ?? 'All'},
      {'key': 'lab', 'label': l10n?.categoryLabs ?? 'Labs'},
      {'key': 'expert', 'label': l10n?.categoryExperts ?? 'Experts & KVK'},
      {'key': 'research', 'label': l10n?.categoryResearch ?? 'Research'},
      {'key': 'government', 'label': l10n?.categoryGovernment ?? 'Government'},
      {'key': 'disease_help', 'label': l10n?.categoryDiseaseHelp ?? 'Disease Help'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat['label']!),
              selected: isSelected,
              onSelected: (_) => _onCategorySelected(cat['key']!),
              selectedColor: AppTheme.darkGreen,
              backgroundColor: const Color(0xFFEAF1DD),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.darkGreen,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppTheme.darkGreen : const Color(0xFFD3E0C1),
                  width: 1,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(AppLocalizations? l10n) {
    switch (_state) {
      case _HelpDeskState.locating:
      case _HelpDeskState.searching:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.darkGreen),
              ),
              const SizedBox(height: 16),
              Text(
                _state == _HelpDeskState.locating
                    ? (l10n?.helpDeskLocating ?? 'Acquiring your location...')
                    : (l10n?.helpDeskSearching ?? 'Finding agricultural support near you...'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A6B35),
                ),
              ),
            ],
          ),
        );

      case _HelpDeskState.serviceDisabled:
        return _buildStatusState(
          icon: Icons.location_disabled,
          title: 'Location Disabled',
          message: l10n?.helpDeskLocationDisabled ??
              'Location services are turned off. Please enable location to find nearby agricultural support.',
          actionLabel: l10n?.helpDeskTryAgain ?? 'Try Again',
          onAction: () => _loadNearbyPlaces(),
        );

      case _HelpDeskState.permissionDenied:
        return _buildStatusState(
          icon: Icons.location_off,
          title: 'Permission Required',
          message: l10n?.helpDeskPermissionDenied ??
              'Location permission is required to find agricultural support near you.',
          actionLabel: l10n?.helpDeskTryAgain ?? 'Try Again',
          onAction: () => _loadNearbyPlaces(),
        );

      case _HelpDeskState.permissionPermanentlyDenied:
        return _buildStatusState(
          icon: Icons.settings,
          title: 'Permission Disabled',
          message: l10n?.helpDeskPermissionPermDenied ??
              'Location permission is permanently disabled. Please enable it in Settings.',
          actionLabel: l10n?.helpDeskOpenSettings ?? 'Open Settings',
          onAction: () => Geolocator.openAppSettings(),
        );

      case _HelpDeskState.error:
        return _buildStatusState(
          icon: Icons.cloud_off,
          title: 'Connection Notice',
          message: _errorMessage ??
              (l10n?.helpDeskOfflineError ??
                  'Unable to load nearby agricultural services. Please check your internet connection and try again.'),
          actionLabel: l10n?.helpDeskTryAgain ?? 'Try Again',
          onAction: () => _loadNearbyPlaces(forceRefresh: true),
        );

      case _HelpDeskState.empty:
        return _buildEmptyState(l10n);

      case _HelpDeskState.success:
        if (_filteredPlaces.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 48, color: Color(0xFF88A07A)),
                  const SizedBox(height: 12),
                  Text(
                    'No results for selected category within ${_searchRadiusMeters ~/ 1000} km.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A7250),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _expandSearchRadius,
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: Text(
                      l10n?.helpDeskSearchWider(((_searchRadiusMeters + 15000) ~/ 1000).toString()) ??
                          'Search Wider Area (${(_searchRadiusMeters + 15000) ~/ 1000} km)',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _loadNearbyPlaces(forceRefresh: true),
          color: AppTheme.darkGreen,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: _filteredPlaces.length + 1,
            itemBuilder: (context, index) {
              if (index < _filteredPlaces.length) {
                return HelpDeskCard(place: _filteredPlaces[index]);
              }
              // Footer button to expand search area
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _expandSearchRadius,
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: Text(
                      l10n?.helpDeskSearchWider(((_searchRadiusMeters + 15000) ~/ 1000).toString()) ??
                          'Search Wider Area (${(_searchRadiusMeters + 15000) ~/ 1000} km)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkGreen,
                      side: const BorderSide(color: Color(0xFF9CB58A), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              );
            },
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState(AppLocalizations? l10n) {
    final nextRadiusKm = (_searchRadiusMeters + 15000) ~/ 1000;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF1DD),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_city, size: 48, color: Color(0xFF5A7250)),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.helpDeskNoResults ?? 'No agricultural support found nearby.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No registered agricultural institutions were found within ${_searchRadiusMeters ~/ 1000} km of your location.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B8060),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _expandSearchRadius,
              icon: const Icon(Icons.travel_explore, size: 18),
              label: Text(
                l10n?.helpDeskSearchWider(nextRadiusKm.toString()) ?? 'Search Wider Area ($nextRadiusKm km)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF1DD),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF5A7250),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
