import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart';
import 'package:squire/view_models/home_view_model.dart';
import 'UnitDetailsScreen.dart';

class ArmyListLoadedScreen extends StatelessWidget {
  final ListPa armyList;

  ArmyListLoadedScreen({required this.armyList, super.key});

  // --- Theme Colors for Consistency ---
  final Color _scaffoldBackground = const Color(0xFF121212); // Deep dark gray
  final Color _cardBackground = const Color(
    0xFF1F1F1F,
  ); // Slightly lighter for contrast
  final Color _primaryText = Colors.white;
  final Color _secondaryText = Colors.white70;
  final Color _accentColor = Colors.grey.shade400; // Bright accent

  // Helper function to format unit ID into asset paths (e.g., "30123" -> "assets/standees/30123.jpg")
  String _getImagePath(String? id, {String type = 'unit'}) {
    // Define the base path for clarity and robustness
    const String basePath = 'assets/standees/';

    if (id == null || id.isEmpty) {
      // Return a generic placeholder if the ID is missing (works because of 'assets/' prefix)
      return '${basePath}placeholder_$type.jpg';
    }
    // FIX: Prepend the full basePath to the ID path.
    return '$basePath$id.jpg';
  }

  // Helper to build an image widget, handling potential errors
  Widget _buildUnitImage(String imagePath, {double size = 150.0}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback widget if the image asset is not found
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey.shade800, // Dark background for placeholder
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Center(
              child: Text(
                '${imagePath.split('/').last.split('.').first}\nNo Image',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: size * 0.1,
                  fontFamily: 'Garamond', // Applied Garamond font
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground, // Apply dark background
      appBar: AppBar(
        title: Text(
          'Tactical Tracker',
          style: TextStyle(
            fontFamily: 'Tuff', // Applied custom font
            fontSize: 24,
            color: _primaryText,
          ),
        ),
        backgroundColor: _cardBackground, // Apply dark header
        foregroundColor: _primaryText,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Commander Portrait (Left Side) ---
              SizedBox(
                width: 130, // Slightly wider for larger image
                child: Column(
                  children: [
                    Text(
                      'Commander',
                      style: TextStyle(
                        fontFamily: 'Tuff', // Applied custom font
                        fontSize: 16,
                        color: _accentColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Use the Commander's ID for the image path
                    _buildUnitImage(
                      _getImagePath(
                        armyList.commanderDetails?.id ?? '',
                        type: 'commander',
                      ),
                      size: 120, // Larger image
                    ),
                    const SizedBox(height: 8),
                    Text(
                      armyList.commanderName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryText,
                        fontFamily: 'Tuff', // Applied custom font
                      ),
                    ),
                  ],
                ),
              ),

              VerticalDivider(
                width: 24,
                thickness: 2,
                color: Colors.white12,
              ), // Dark theme divider
              // --- 2. Combat Units (Center, Horizontal Scrollable) ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Combat Units (${armyList.combatUnits.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tuff', // Applied custom font
                        fontSize: 20,
                        color: _primaryText,
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: Consumer<HomeViewModel>(
                        builder: (context, viewModel, child) {
                          // Ensure we use the latest state from the view model
                          final units = viewModel.listPa?.combatUnits ?? [];

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: units
                                  .map(
                                    (unit) => _buildUnitCard(
                                      context,
                                      unit,
                                      isCombat: true,
                                      viewModel: viewModel,
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              VerticalDivider(
                width: 24,
                thickness: 2,
                color: Colors.white12,
              ), // Dark theme divider
              // --- 3. NCUs (Right Side, Vertical Column) ---
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NCUs (${armyList.ncus.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tuff', // Applied custom font
                        fontSize: 18,
                        color: _primaryText,
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: Consumer<HomeViewModel>(
                        builder: (context, viewModel, child) {
                          // Ensure we use the latest state from the view model
                          final ncus = viewModel.listPa?.ncus ?? [];

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ncus
                                  .map(
                                    (unit) => _buildNcuCard(
                                      context,
                                      unit,
                                      viewModel: viewModel,
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Provider.of<HomeViewModel>(
            context,
            listen: false,
          ).resetAllActivations();
          // Use dark theme appropriate SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All units reset to unactivated.',
                style: TextStyle(color: Colors.black, fontFamily: 'Garamond'),
              ),
              backgroundColor: _accentColor,
              duration: const Duration(milliseconds: 1500),
            ),
          );
        },
        label: Text(
          'Reset Activations',
          style: TextStyle(
            fontFamily: 'Tuff', // Applied custom font
            color: Colors.black,
          ),
        ),
        icon: const Icon(Icons.refresh, color: Colors.black),
        backgroundColor: _accentColor,
      ),
    );
  }

  // --- Widget Builders for Units/NCUs ---

  // Combat Unit Card (Horizontal)
  Widget _buildUnitCard(
    BuildContext context,
    UnitEntry unit, {
    required bool isCombat,
    required HomeViewModel viewModel,
  }) {
    final currentUnitState = viewModel.findUnitState(unit);
    final baseWounds = currentUnitState.unitDetails?.baseWounds ?? 1;
    final isDestroyed = currentUnitState.currentWounds >= baseWounds;

    final unitId = currentUnitState.unitDetails?.id;
    final attachmentId = currentUnitState.attachmentDetails?.id;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnitDetailsScreen(unit: currentUnitState),
          ),
        );
      },
      child: Container(
        width: 200, // Significantly wider for better visual impact
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        child: Card(
          elevation: 8,
          color: _cardBackground, // Apply dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              // Change border color based on status
              color: currentUnitState.isActivated
                  ? Colors
                        .green
                        .shade600 // Activated: Green
                  : isDestroyed
                  ? Colors
                        .red
                        .shade900 // Destroyed: Dark Red
                  : Colors.grey.shade700, // Ready: Subtle gray
              width: currentUnitState.isActivated ? 4 : 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Unit Portrait
                    _buildUnitImage(_getImagePath(unitId), size: 150),
                    const SizedBox(height: 12),

                    // Unit Name
                    Text(
                      unit.unitName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryText,
                        fontFamily: 'Tuff', // Applied custom font
                        decoration: isDestroyed
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Colors.redAccent,
                        decorationThickness: 2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Status Indicators (Wounds & Activation Toggle)
                    _buildStatusIndicators(
                      context,
                      viewModel,
                      currentUnitState,
                      baseWounds,
                      isCombat,
                    ),
                  ],
                ),
              ),

              // Attachment Image (Top Right Corner)
              if (attachmentId != null)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _accentColor, // Use accent color
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    // Use attachment ID for image path
                    child: _buildUnitImage(
                      _getImagePath(attachmentId, type: 'attachment'),
                      size: 50, // Slightly larger attachment icon
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // NCU Card (Vertical on Right)
  Widget _buildNcuCard(
    BuildContext context,
    UnitEntry unit, {
    required HomeViewModel viewModel,
  }) {
    final currentUnitState = viewModel.findUnitState(unit);
    final unitId = currentUnitState.unitDetails?.id;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnitDetailsScreen(unit: currentUnitState),
          ),
        );
      },
      child: Container(
        width: 100, // Ensure card fits the column width
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 4,
          color: _cardBackground, // Apply dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: currentUnitState.isActivated
                  ? _accentColor // Activated: Accent color
                  : Colors.grey.shade700, // Ready: Subtle gray
              width: currentUnitState.isActivated ? 3 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              children: [
                // Unit Image
                _buildUnitImage(_getImagePath(unitId, type: 'ncu'), size: 70),
                const SizedBox(height: 4),
                Text(
                  unit.unitName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _secondaryText,
                    fontFamily: 'Garamond', // Applied Garamond font
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // NCU Activation Toggle
                _buildActivationToggle(
                  viewModel,
                  currentUnitState,
                  isNcu: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Common Status Indicator Row
  Widget _buildStatusIndicators(
    BuildContext context,
    HomeViewModel viewModel,
    UnitEntry currentUnitState,
    int baseWounds,
    bool isCombat,
  ) {
    final isDestroyed = currentUnitState.currentWounds >= baseWounds;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Wounds Indicator (for Combat Units only)
        if (isCombat)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isDestroyed
                    ? Colors.red.shade900
                    : Colors.red.shade700.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDestroyed
                      ? Colors.red.shade500
                      : Colors.red.shade600,
                ),
              ),
              child: Text(
                isDestroyed
                    ? 'DESTROYED'
                    : 'W: ${currentUnitState.currentWounds}/$baseWounds',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isDestroyed ? Colors.white : Colors.white,
                  fontFamily: 'Garamond', // Applied Garamond font
                ),
              ),
            ),
          ),

        if (isCombat) const SizedBox(width: 8),

        // Activation Toggle
        _buildActivationToggle(viewModel, currentUnitState, isNcu: !isCombat),
      ],
    );
  }

  // Common Activation Toggle Widget
  Widget _buildActivationToggle(
    HomeViewModel viewModel,
    UnitEntry currentUnitState, {
    required bool isNcu,
  }) {
    final Color activeColor = isNcu
        ? _accentColor // NCU Activated: Accent
        : Colors.green.shade500; // CU Activated: Green
    final Color inactiveColor = isNcu
        ? Colors
              .grey
              .shade700 // NCU Ready: Dark Gray
        : Colors.red.shade700; // CU Ready: Dark Red

    return InkWell(
      onTap: () {
        viewModel.toggleActivation(
          currentUnitState.unitName,
          attachmentName: currentUnitState.attachmentName,
        );
      },
      child: Container(
        width: 30, // Increased size
        height: 30, // Increased size
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentUnitState.isActivated ? activeColor : inactiveColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          currentUnitState.isActivated
              ? Icons.check
              : Icons.timer_off, // Using timer_off for inactive state
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// Extension to help ViewModel consumers find the correct state
extension HomeViewModelHelper on HomeViewModel {
  UnitEntry findUnitState(UnitEntry unit) {
    // Determine if the unit is a Combat Unit (CU) based on presence in the CU list.
    // This is a reliable check as CUs and NCUs are mutually exclusive lists in ListPa.
    final isCombat =
        listPa?.combatUnits.any(
          (u) =>
              u.unitName == unit.unitName &&
              u.attachmentName == unit.attachmentName,
        ) ??
        false;

    if (isCombat) {
      return listPa?.combatUnits.firstWhere(
            (u) =>
                u.unitName == unit.unitName &&
                u.attachmentName == unit.attachmentName,
            orElse: () => unit,
          ) ??
          unit;
    } else {
      return listPa?.ncus.firstWhere(
            (u) =>
                u.unitName == unit.unitName &&
                u.attachmentName == unit.attachmentName,
            orElse: () => unit,
          ) ??
          unit;
    }
  }
}
