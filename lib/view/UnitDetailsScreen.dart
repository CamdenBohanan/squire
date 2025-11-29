import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart' as army_data;
import 'package:squire/view_models/home_view_model.dart';
import 'dart:math'; // Required for Random and max

class UnitDetailsScreen extends StatefulWidget {
  final army_data.UnitEntry unit;

  const UnitDetailsScreen({required this.unit, super.key});

  @override
  State<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends State<UnitDetailsScreen> {
  // --- Theme Colors and Fonts for Consistency ---
  final Color _scaffoldBackground = const Color(0xFF121212); // Deep dark gray
  final Color _cardBackground = const Color(
    0xFF1F1F1F,
  ); // Slightly lighter for contrast
  final Color _primaryText = Colors.white;
  final Color _secondaryText = Colors.white70;
  final Color _accentColor = Colors.grey.shade400; // Bright accent

  // State to track which attack profile is selected (e.g., 'melee' or 'long')
  String _selectedAttackType = 'melee';

  // State to track which specific Order abilities are currently active.
  // This is locally managed and must be reset on unit deactivation.
  final Set<String> _activeOrders = {};

  @override
  void initState() {
    super.initState();
    // Default to the first attack type available if it's not melee
    final attackProfiles = widget.unit.unitDetails?.attacks ?? [];
    if (!attackProfiles.any((p) => p.type == 'melee') &&
        attackProfiles.isNotEmpty) {
      _selectedAttackType = attackProfiles.first.type;
    }
  }

  // --- REVISED AND ROBUST IMAGE HELPER ---
  Widget _buildUnitImage(
    String viewModelPath, {
    required double size,
    required bool isMain,
  }) {
    // Fallback widget function for consistency
    Widget fallbackWidget(String path) {
      // Use the last part of the path as a readable ID for the placeholder text
      final displayId = path.split('/').last.split('.').first.isNotEmpty
          ? path.split('/').last.split('.').first
          : 'Unit';

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade800, // Dark background for placeholder
          borderRadius: BorderRadius.circular(isMain ? 12.0 : 8.0),
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Center(
          child: Text(
            '$displayId\nNo Image',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: size * 0.1,
              fontFamily: 'Garamond',
            ),
          ),
        ),
      );
    }

    // 1. CRITICAL GUARD: Check if the ViewModel returned a known error placeholder string
    // or an empty path. If so, immediately show the fallback.
    final bool isPlaceholderError =
        viewModelPath.contains('[CLICK USE]') || viewModelPath.isEmpty;

    if (isPlaceholderError) {
      return fallbackWidget(viewModelPath);
    }

    // 2. PATH FIX: Assume the viewModelPath is the complete asset path (e.g., 'assets/...')
    // Removed the redundant 'assets/' prefix to prevent the double path error.
    final fullAssetPath = viewModelPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(isMain ? 12.0 : 8.0),
      child: Image.asset(
        fullAssetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The errorBuilder handles genuine file-not-found issues that pass the initial guard
        errorBuilder: (context, error, stackTrace) {
          return fallbackWidget(fullAssetPath);
        },
      ),
    );
  }

  // --- END REVISED IMAGE HELPER ---

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HomeViewModel>(context);

    // CRITICAL FIX: Use the ViewModel helper to get the latest state reactively.
    // This simplifies the build method and ensures wound/activation data is current.
    final army_data.UnitEntry currentUnitState = viewModel.getUnitState(
      widget.unit,
    );

    // Check if the unit is a Combat Unit (has defense value)
    final isCombatUnit = currentUnitState.unitDetails?.defense != null;

    return Scaffold(
      backgroundColor: _scaffoldBackground, // Apply dark background
      appBar: AppBar(
        title: Text(
          currentUnitState.unitName,
          style: TextStyle(
            fontFamily: 'Tuff', // Applied custom font
            fontSize: 22,
            color: _primaryText,
          ),
        ),
        backgroundColor: _cardBackground, // Apply dark header
        foregroundColor: _primaryText,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- UNIT AND ATTACHMENT PORTRAITS ---
            _buildPortraitsRow(currentUnitState, viewModel), // Pass viewModel

            const SizedBox(height: 20),

            // --- UNIT IDENTIFICATION & ACTIVATION ---
            Card(
              color: _cardBackground, // Apply dark card color
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUnitState.unitName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                        fontFamily: 'Tuff',
                      ),
                    ),
                    if (currentUnitState.attachmentName != null)
                      Text(
                        'Attached: ${currentUnitState.attachmentName}',
                        style: TextStyle(
                          fontSize: 18,
                          color: _secondaryText,
                          fontFamily: 'Garamond',
                        ),
                      ),
                    Divider(height: 20, color: Colors.white12),
                    _buildActivationTracker(
                      context,
                      currentUnitState,
                      viewModel,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- WOUND COUNTER (Combat Units Only) ---
            if (isCombatUnit)
              _buildWoundCounter(context, currentUnitState, viewModel),

            const SizedBox(height: 20),

            // --- ROLL SECTION (Combat Units Only) ---
            if (isCombatUnit)
              _buildRollsSection(context, currentUnitState, viewModel),

            // --- UNIT ABILITIES AND RULES ---
            _buildAbilitiesSection(context, currentUnitState, viewModel),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Portrait Builder Section ---

  Widget _buildPortraitsRow(army_data.UnitEntry unit, HomeViewModel viewModel) {
    final unitData = unit.unitDetails;
    final attachmentData = unit.attachmentDetails;
    const double mainImageSize = 120.0;
    const double secondaryImageSize = 90.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Main Unit Portrait (Always present)
        _buildUnitPortrait(
          viewModel, // Pass viewModel
          unitData?.role == 'ncu' ? 'NCU' : 'Unit', // Label logic
          unitData,
          mainImageSize,
          isMain: true,
        ),

        // 2. Attachment Portrait (If present)
        if (attachmentData != null) ...[
          const SizedBox(width: 20),
          _buildUnitPortrait(
            viewModel, // Pass viewModel
            'Attachment',
            attachmentData,
            secondaryImageSize,
            isMain: false,
          ),
        ],
      ],
    );
  }

  Widget _buildUnitPortrait(
    HomeViewModel viewModel, // Added viewModel
    String label,
    army_data.ArmyUnitData? data,
    double size, {
    required bool isMain,
  }) {
    final name = data?.name ?? 'Unknown';
    final title = data?.title;

    // Use the ViewModel's helper to get the image path
    final imagePath = viewModel.getUnitImagePath(
      data,
      type: data?.role ?? 'unit',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMain ? 18 : 16,
            color: isMain ? _primaryText : _accentColor, // Differentiate roles
            fontFamily: 'Tuff',
          ),
        ),
        const SizedBox(height: 8),
        _buildUnitImage(
          imagePath, // Use the path returned by the ViewModel
          size: size,
          isMain: isMain,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size,
          child: Text(
            title ?? name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _secondaryText,
              fontFamily: 'Garamond',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- End Portrait Builder Section ---

  Widget _buildActivationTracker(
    BuildContext context,
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activation Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _primaryText,
            fontFamily: 'Tuff',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: unit.isActivated
                ? Colors.green.shade900.withOpacity(0.5)
                : Colors.red.shade900.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: unit.isActivated
                  ? Colors.green.shade600
                  : Colors.red.shade600,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unit.isActivated ? 'ACTIVATED' : 'UNACTIVATED',
                style: TextStyle(
                  color: unit.isActivated ? _accentColor : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Garamond',
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // If the unit is currently activated, clicking this button means we are
                  // resetting it. We must clear the local temporary active orders state.
                  if (unit.isActivated) {
                    setState(() {
                      _activeOrders.clear();
                    });
                  }
                  viewModel.toggleActivation(
                    unit.unitName,
                    attachmentName: unit.attachmentName,
                  );
                },
                icon: Icon(
                  unit.isActivated ? Icons.undo : Icons.check_circle_outline,
                ),
                label: Text(
                  unit.isActivated ? 'Reset' : 'Activate',
                  style: const TextStyle(fontFamily: 'Tuff'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: unit.isActivated
                      ? Colors
                            .amber
                            .shade700 // Reset button color
                      : _accentColor, // Activate button color
                  foregroundColor: Colors.black, // Ensure contrast
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWoundCounter(
    BuildContext context,
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    // Get the parsed wounds from the unit details, defaulting to 0 if null.
    int baseWounds = unit.unitDetails?.baseWounds ?? 0;
    int totalMaxWounds = 0;

    // --- START WOUND CALCULATION FIX ---
    if (baseWounds > 0 && baseWounds <= 3) {
      // If baseWounds is a low value (1-3), we assume it's "wounds per rank"
      // for a standard 4-rank combat unit (Cavalry, Infantry).
      totalMaxWounds = baseWounds * 4; // e.g., 3 * 4 = 12
    } else if (baseWounds > 0) {
      // Use the baseWounds directly for Solos/Monsters (e.g., 4 or 6 wounds),
      // or if the data already contains the total (e.g., 12 or 20).
      totalMaxWounds = baseWounds;
    } else {
      // Fallback default for combat units with missing data.
      totalMaxWounds = 12;
    }

    final maxWounds = totalMaxWounds;
    // --- END WOUND CALCULATION FIX ---

    final woundsTaken = unit.currentWounds;
    final woundsRemaining = maxWounds - woundsTaken;
    final isDestroyed = woundsRemaining <= 0;

    return Card(
      color: _cardBackground, // Apply dark card color
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wound Tracker',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryText,
                fontFamily: 'Tuff',
              ),
            ),
            Divider(height: 20, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement Wounds Button (Takes Damage)
                _buildWoundButton(
                  icon: Icons.exposure_plus_1, // Damage taken is +1 wound
                  color: Colors.red.shade700,
                  onPressed: woundsRemaining > 0
                      ? () => viewModel.updateWounds(
                          unit.unitName,
                          attachmentName: unit.attachmentName,
                          newWounds: woundsTaken + 1,
                        )
                      : null,
                ),

                // Wound Display - SHOWS WOUNDS REMAINING
                Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDestroyed ? Colors.red.shade900 : Colors.black,
                    border: Border.all(color: Colors.red.shade600),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Wounds Remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDestroyed ? Colors.white : Colors.white70,
                            fontFamily: 'Garamond',
                          ),
                        ),
                        Text(
                          '$woundsRemaining / $maxWounds',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: isDestroyed ? Colors.white : _accentColor,
                            fontFamily: 'Tuff',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Increment Wounds Button (Heals)
                _buildWoundButton(
                  icon: Icons.exposure_minus_1, // Healing is -1 wound
                  color: Colors.green.shade700,
                  onPressed: woundsTaken > 0
                      ? () => viewModel.updateWounds(
                          unit.unitName,
                          attachmentName: unit.attachmentName,
                          newWounds: woundsTaken - 1,
                        )
                      : null,
                ),
              ],
            ),
            if (isDestroyed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    'Unit Destroyed/Broken!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tuff',
                    ),
                  ),
                ),
              ),
            // Display Current Rank Status (Wounds Remaining)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Text(
                  _getCurrentRankText(maxWounds, woundsTaken),
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: _secondaryText,
                    fontFamily: 'Garamond',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentRankText(int maxWounds, int woundsTaken) {
    final woundsRemaining = maxWounds - woundsTaken;

    // Use a simpler rank definition based on thirds of the max wounds.
    if (woundsRemaining > maxWounds * 2 / 3) {
      return 'Current Rank: 3 (Full Dice)';
    } else if (woundsRemaining > maxWounds * 1 / 3) {
      return 'Current Rank: 2 (Mid Dice)';
    } else if (woundsRemaining > 0) {
      return 'Current Rank: 1 (Low Dice)';
    } else {
      return 'Unit Routed/Destroyed!';
    }
  }

  Widget _buildWoundButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(15),
        elevation: 5,
        shadowColor: Colors.black,
      ),
      child: Icon(icon, size: 24, color: Colors.white),
    );
  }

  // --- Reusable Modifier Button Row ---
  Widget _buildModifierControls({
    required String label,
    required int currentValue,
    required Color color,
    required void Function(int) onUpdate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
              fontFamily: 'Garamond',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => onUpdate(currentValue - 1),
                    tooltip: 'Decrease Modifier',
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      (currentValue > 0 ? '+' : '') + currentValue.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _primaryText,
                        fontFamily: 'Tuff',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: Colors.green.shade400,
                    ),
                    onPressed: () => onUpdate(currentValue + 1),
                    tooltip: 'Increase Modifier',
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () => onUpdate(0),
                tooltip: 'Reset Modifier',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRollsSection(
    BuildContext context,
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    final attackProfiles = unit.unitDetails?.attacks ?? [];

    final availableAttackTypes = attackProfiles
        .map((p) => p.type)
        .toSet()
        .toList();
    final hasMultipleAttackTypes = availableAttackTypes.length > 1;

    // Default dice/target to safe values if unitDetails is null
    final attackDice = unit.unitDetails != null
        ? viewModel.getAttackDiceForUnit(unit, _selectedAttackType)
        : 0;
    final toHitTarget = unit.unitDetails != null
        ? viewModel.getToHitTarget(unit, _selectedAttackType)
        : 4;

    final selectedAttackName = attackProfiles
        .firstWhere(
          (p) => p.type == _selectedAttackType,
          orElse: () => army_data.AttackProfile(
            name: 'No Attack',
            type: '',
            hit: 0,
            dice: [],
          ),
        )
        .name;

    final defenseSaveTarget = unit.unitDetails != null
        ? viewModel.getDefenseSaveTarget(unit)
        : 3;
    final defenseDice = unit.unitDetails != null
        ? viewModel.getDefenseDiceCount(unit)
        : 0;
    final moraleTarget = unit.unitDetails != null
        ? viewModel.getMoraleTarget(unit)
        : 7;

    return Card(
      color: _cardBackground, // Apply dark card color
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combat Rolls',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryText,
                fontFamily: 'Tuff',
              ),
            ),
            Divider(height: 10, color: Colors.white12),

            // --- Attack Type Selector (only if multiple types exist) ---
            if (hasMultipleAttackTypes)
              _buildAttackTypeSelector(context, availableAttackTypes),

            const SizedBox(height: 15),

            // --- Attack Roll Modifier ---
            _buildModifierControls(
              label: 'Attack Roll Modifier (Target Roll: $toHitTarget+)',
              currentValue: unit.attackModifier,
              color: Colors.red.shade400,
              onUpdate: (value) => viewModel.updateAttackModifier(
                unit.unitName,
                attachmentName: unit.attachmentName,
                modifier: value,
              ),
            ),

            // --- Attack Roll Button ---
            _buildRollButton(
              context,
              '$selectedAttackName Roll (${attackDice}D6 | Hit $toHitTarget+)',
              Icons.track_changes_outlined,
              Colors.red.shade700,
              () => _showAttackRollResult(
                context,
                selectedAttackName,
                attackDice,
                toHitTarget,
              ),
            ),

            const SizedBox(height: 20),

            // --- Save Roll Modifier (Target) ---
            _buildModifierControls(
              label:
                  'Defense Roll Target Modifier (Target Save: $defenseSaveTarget+)',
              currentValue: unit.defenseModifier,
              color: Colors.blue.shade400,
              onUpdate: (value) => viewModel.updateDefenseModifier(
                unit.unitName,
                attachmentName: unit.attachmentName,
                modifier: value,
              ),
            ),

            // Defense Dice Modifier
            _buildModifierControls(
              label: 'Defense Roll Dice Modifier (Total Dice: $defenseDice D6)',
              currentValue: unit.defenseDiceModifier,
              color: _accentColor,
              onUpdate: (value) => viewModel.updateDefenseDiceModifier(
                unit.unitName,
                attachmentName: unit.attachmentName,
                modifier: value,
              ),
            ),

            // --- Save Roll Button ---
            _buildRollButton(
              context,
              'Defense Roll (${defenseDice}D6 | Save $defenseSaveTarget+)',
              Icons.health_and_safety_outlined,
              Colors.blue.shade700,
              () => _showRollResult(
                context,
                'Defense Save',
                defenseDice,
                defenseSaveTarget,
              ),
            ),

            const SizedBox(height: 20),

            // --- Morale Roll Modifier ---
            _buildModifierControls(
              label: 'Morale Check Modifier (Target Roll: $moraleTarget+)',
              currentValue: unit.moraleModifier,
              color: Colors.purple.shade400,
              onUpdate: (value) => viewModel.updateMoraleModifier(
                unit.unitName,
                attachmentName: unit.attachmentName,
                modifier: value,
              ),
            ),

            // --- Morale Roll Button ---
            _buildRollButton(
              context,
              'Morale Check ($moraleTarget+)',
              Icons.heart_broken,
              Colors.purple.shade700,
              () =>
                  _showMoraleRollResult(context, moraleTarget, unit, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  // --- ABILITIES SECTION FOR NCUs AND COMBAT UNITS (MODIFIED) ---
  Widget _buildAbilitiesSection(
    BuildContext context,
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    final abilities = viewModel.getUnitAbilities(unit);

    if (abilities.isEmpty) {
      return const SizedBox.shrink(); // Hide if no abilities are loaded yet
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Card(
          color: _cardBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abilities & Rules',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _primaryText,
                    fontFamily: 'Tuff',
                  ),
                ),
                Divider(height: 20, color: Colors.white12),
                ...abilities.map((abilityString) {
                  // CRITICAL FIX: Parse the ViewModel's clean output: "**Name**:\nEffect Text"
                  final parts = abilityString.split(
                    ':\n',
                  ); // Split by the clean delimiter
                  final nameWithStars =
                      parts.first; // e.g., "**Order: Set for Charge**"
                  final fullAbilityName = nameWithStars
                      .replaceAll('**', '')
                      .trim();
                  final effect = parts.length > 1
                      ? parts
                            .sublist(1)
                            .join(':\n')
                            .trim() // Use join(':\n') to handle colons in text
                      : 'Rule text unavailable.';

                  final isOrder = fullAbilityName.startsWith('Order:');

                  // NEW: Check state via ViewModel
                  // This calculation is retained for visual status display
                  final isUsed = isOrder
                      ? viewModel.isAbilityUsed(unit, fullAbilityName)
                      : false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // Display name without the trailing colon, as the effect is separate
                                fullAbilityName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isUsed // Highlight color based on VM state
                                      ? Colors.yellow.shade400
                                      : _accentColor,
                                  fontFamily: 'Garamond',
                                ),
                              ),
                              Text(
                                effect,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _secondaryText,
                                  fontFamily: 'Garamond',
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. Order Toggle Button (Now non-functional)
                        if (isOrder)
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: ElevatedButton(
                              onPressed: null, // Functionality removed
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                minimumSize:
                                    Size.zero, // Make button size fit content
                                backgroundColor:
                                    isUsed // Color based on VM state
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                isUsed ? '' : '', // Label based on VM state
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Tuff',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- UPDATED Attack Type Selector (Themed) ---
  Widget _buildAttackTypeSelector(
    BuildContext context,
    List<String> availableTypes,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black54, // Dark background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: availableTypes.contains(_selectedAttackType)
              ? _selectedAttackType
              : availableTypes.first,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: _accentColor),
          elevation: 16,
          dropdownColor: Colors.black87,
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontFamily: 'Garamond',
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedAttackType = newValue;
              });
            }
          },
          items: availableTypes.map<DropdownMenuItem<String>>((String value) {
            String label;
            switch (value) {
              case 'melee':
                label = 'Melee Attack';
                break;
              case 'long':
                label = 'Ranged Attack (Long)';
                break;
              case 'short':
                label = 'Ranged Attack (Short)';
                break;
              default:
                label = '${value[0].toUpperCase()}${value.substring(1)} Attack';
            }

            return DropdownMenuItem<String>(
              value: value,
              child: Text(label, style: TextStyle(color: _primaryText)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Themed Roll Button ---
  Widget _buildRollButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Tuff', // Applied custom font
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 5,
      ),
    );
  }

  // --- Themed Attack Roll Dialog (Untruncated) ---
  void _showAttackRollResult(
    BuildContext context,
    String rollType,
    int numberOfDice,
    int toHit,
  ) {
    if (numberOfDice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Cannot roll: Unit is destroyed or has 0 attack dice.",
            style: TextStyle(color: Colors.black, fontFamily: 'Garamond'),
          ),
          backgroundColor: _accentColor,
        ),
      );
      return;
    }

    final rolls = List<int>.generate(
      numberOfDice,
      (_) => 1 + Random().nextInt(6),
    );
    final hits = rolls.where((r) => r >= toHit).length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          title: Text(
            '$rollType Roll Result',
            style: TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tuff',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dice rolled: $numberOfDice (Hit on $toHit+)',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Hits: $hits',
                style: TextStyle(
                  color: hits > 0 ? Colors.green.shade400 : Colors.red.shade400,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tuff',
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Individual Rolls:',
                style: TextStyle(color: _accentColor, fontFamily: 'Garamond'),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: rolls.map((roll) {
                  final isSuccess = roll >= toHit;
                  return Chip(
                    label: Text(
                      roll.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: isSuccess
                        ? Colors.green.shade300
                        : Colors.grey.shade400,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }

  // --- Themed Roll Dialog (Generic - Untruncated) ---
  void _showRollResult(
    BuildContext context,
    String rollType,
    int numberOfDice,
    int target,
  ) {
    if (numberOfDice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Cannot roll: Unit is destroyed or has 0 defense dice.",
            style: TextStyle(color: Colors.black, fontFamily: 'Garamond'),
          ),
          backgroundColor: _accentColor,
        ),
      );
      return;
    }

    final rolls = List<int>.generate(
      numberOfDice,
      (_) => 1 + Random().nextInt(6),
    );
    final successes = rolls.where((r) => r >= target).length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          title: Text(
            '$rollType Result',
            style: TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tuff',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dice rolled: $numberOfDice (Success on $target+)',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Successes: $successes',
                style: TextStyle(
                  color: successes > 0
                      ? Colors.blue.shade400
                      : Colors.red.shade400,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tuff',
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Individual Rolls:',
                style: TextStyle(color: _accentColor, fontFamily: 'Garamond'),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: rolls.map((roll) {
                  final isSuccess = roll >= target;
                  return Chip(
                    label: Text(
                      roll.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: isSuccess
                        ? Colors.blue.shade300
                        : Colors.grey.shade400,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }

  // --- Themed Morale Roll Dialog (Untruncated & Clarified) ---
  void _showMoraleRollResult(
    BuildContext context,
    int target,
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    final roll1 = 1 + Random().nextInt(6);
    final roll2 = 1 + Random().nextInt(6);
    final modifier = unit.moraleModifier;
    final total = roll1 + roll2 + modifier;

    // Pass if the total is EQUAL to or HIGHER than the Morale Target (MV)
    final success = total >= target;
    final resultText = success ? 'Passed' : 'Failed (Routed/Panicked)';
    final resultColor = success ? Colors.green.shade600 : Colors.red.shade600;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          title: Text(
            'Morale Check',
            style: TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tuff',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Morale Value (MV): $target+',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const SizedBox(height: 10),
              Text(
                'Rolls: $roll1 + $roll2',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              Text(
                'Modifier: ${modifier > 0 ? '+' : ''}$modifier',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const Divider(),
              Text(
                'Total Roll: $total (Needed $target+ to Pass)',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tuff',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Check Result: $resultText',
                style: TextStyle(
                  color: resultColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tuff',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }
}
