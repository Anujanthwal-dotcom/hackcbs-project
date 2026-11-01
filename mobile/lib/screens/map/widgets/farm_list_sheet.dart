import 'package:flutter/material.dart';
import '../../../models/farm_model.dart';

/// A draggable bottom sheet that lists all of the user's farms with selection
/// and deletion capabilities.
class FarmListSheet extends StatelessWidget {
  final List<FarmModel> farms;
  final FarmModel? activeFarm;
  final ValueChanged<FarmModel> onFarmSelected;
  final ValueChanged<FarmModel>? onFarmDeleted;

  const FarmListSheet({
    super.key,
    required this.farms,
    required this.activeFarm,
    required this.onFarmSelected,
    this.onFarmDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    required List<FarmModel> farms,
    required FarmModel? activeFarm,
    required ValueChanged<FarmModel> onFarmSelected,
    ValueChanged<FarmModel>? onFarmDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FarmListSheet(
        farms: farms,
        activeFarm: activeFarm,
        onFarmSelected: onFarmSelected,
        onFarmDeleted: onFarmDeleted,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FarmModel farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E14),
        title: const Text(
          'Delete Farm?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${farm.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // Close bottom sheet
      onFarmDeleted?.call(farm);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A2E14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.agriculture, color: Color(0xFF81C784), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'My Farms (${farms.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Farm list
              Expanded(
                child: farms.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_location_alt_outlined,
                                  color: Colors.white38, size: 48),
                              SizedBox(height: 12),
                              Text(
                                'No farms saved yet.\nUse "Add Pin" or "Mark My Farm" on the map.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: farms.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10, height: 1, indent: 64),
                        itemBuilder: (ctx, i) {
                          final farm = farms[i];
                          final isActive = activeFarm?.id == farm.id;
                          final isPin = farm.boundary.length <= 1;
                          final areaLabel = isPin
                              ? 'Pin location'
                              : farm.formattedArea;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                onFarmSelected(farm);
                              },
                              splashColor: Colors.white10,
                              highlightColor: Colors.white10,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    // Farm icon with active indicator
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFF2E4A22),
                                      ),
                                      child: Icon(
                                        isPin
                                            ? Icons.place
                                            : Icons.agriculture,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Farm name + area
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            farm.name,
                                            style: TextStyle(
                                              color: isActive
                                                  ? const Color(0xFF81C784)
                                                  : Colors.white,
                                              fontSize: 15,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            areaLabel,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (farm.cropType != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              farm.cropType!,
                                              style: const TextStyle(
                                                color: Color(0xFF81C784),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Active check indicator
                                    if (isActive)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.check_circle,
                                            color: Color(0xFF4CAF50), size: 20),
                                      ),

                                    // Delete Farm Button
                                    if (onFarmDeleted != null)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Farm',
                                        onPressed: () => _confirmDelete(context, farm),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
