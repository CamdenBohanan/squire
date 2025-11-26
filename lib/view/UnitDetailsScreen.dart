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

  // --- MOCK IMAGE HELPERS (Copied from ArmyListLoadedScreen for consistency) ---

  // Helper to construct the full asset path
  String _getImagePath(String? id, {required String type}) {
    if (id == null || id.isEmpty) {
      // Return a generic placeholder if the ID is missing
      return 'assets/standees/placeholder_$type.jpg';
    }
    // Use the ID directly with the .jpg extension as specified
    return 'assets/standees/$id.jpg';
  }

  // Helper to build an image widget, handling potential errors
  Widget _buildUnitImage(
    String imagePath, {
    required double size,
    required bool isMain,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMain ? 12.0 : 8.0),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback widget if the image asset is not found (Dark Theme)
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
                '${imagePath.split('/').last.split('.').first}\nNo Image',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: size * 0.1,
                  fontFamily: 'Garamond',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- END MOCK IMAGE HELPERS ---

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HomeViewModel>(context);

    // Get the current state of the unit from the ViewModel
    army_data.UnitEntry currentUnitState = widget.unit;

    // Safely look up the unit in the ViewModel's state to get the latest wounds/modifiers
    army_data.UnitEntry? match;

    // 1. Search Combat Units safely
    final cuList = viewModel.listPa?.combatUnits ?? [];
    final cuMatches = cuList
        .where(
          (u) =>
              u.unitName == widget.unit.unitName &&
              u.attachmentName == widget.unit.attachmentName,
        )
        .toList();

    if (cuMatches.isNotEmpty) {
      match = cuMatches.first;
    }

    // 2. Search NCUs safely if no combat unit match found
    if (match == null) {
      final ncuList = viewModel.listPa?.ncus ?? [];
      final ncuMatches = ncuList
          .where(
            (u) =>
                u.unitName == widget.unit.unitName &&
                u.attachmentName == widget.unit.attachmentName,
          )
          .toList();

      if (ncuMatches.isNotEmpty) {
        match = ncuMatches.first;
      }
    }

    // 3. Update the state reference if a match was found
    if (match != null) {
      currentUnitState = match;
    }

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
            _buildPortraitsRow(currentUnitState),

            const SizedBox(height: 20),

            // --- UNIT IDENTIFICATION ---
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

            // --- ROLL SECTION ---
            if (isCombatUnit)
              _buildRollsSection(context, currentUnitState, viewModel),
          ],
        ),
      ),
    );
  }

  // --- Portrait Builder Section ---

  Widget _buildPortraitsRow(army_data.UnitEntry unit) {
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
          unitData?.role == 'ncu' ? 'NCU' : 'Unit', // Label logic
          unitData,
          mainImageSize,
          isMain: true,
        ),

        // 2. Attachment Portrait (If present)
        if (attachmentData != null) ...[
          const SizedBox(width: 20),
          _buildUnitPortrait(
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
    String label,
    army_data.ArmyUnitData? data,
    double size, {
    required bool isMain,
  }) {
    final id = data?.id;
    final name = data?.name ?? 'Unknown';
    final title = data?.title;

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
          _getImagePath(id, type: data?.role ?? 'unit'),
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
                onPressed: () => viewModel.toggleActivation(
                  unit.unitName,
                  attachmentName: unit.attachmentName,
                ),
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
    // Check if the unit is a Combat Unit (has defense value)
    final isCombatUnit = unit.unitDetails?.defense != null;

    // Get the parsed wounds from the unit details, defaulting to 0 if null.
    int parsedWounds = unit.unitDetails?.baseWounds ?? 0;

    // --- CRITICAL FIX REMOVED ---
    // The previous logic incorrectly forced single-model unit wounds (like 4) up to 12.
    // We now trust the 'baseWounds' value from the data source for the maximum wounds.

    // Final max wounds: use the parsed value, or 12 as a fallback default.
    final maxWounds = parsedWounds > 0 ? parsedWounds : 12;

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

    final attackDice = viewModel.getAttackDiceForUnit(
      unit,
      _selectedAttackType,
    );
    final toHitTarget = viewModel.getToHitTarget(unit, _selectedAttackType);

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

    final defenseSaveTarget = viewModel.getDefenseSaveTarget(unit);
    final defenseDice = viewModel.getDefenseDiceCount(unit);
    final moraleTarget = viewModel.getMoraleTarget(unit);

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

  // --- Themed Attack Roll Dialog ---
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
            '$rollType Roll (Hit $toHit+)',
            style: TextStyle(color: _primaryText, fontFamily: 'Tuff'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rolled $numberOfDice D6:',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: rolls
                    .map(
                      (roll) => Chip(
                        label: Text(
                          roll.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Colors.black, // Chip text is black for contrast
                          ),
                        ),
                        backgroundColor: roll >= toHit
                            ? Colors.green.shade400
                            : Colors.red.shade400,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 15),
              Text(
                'Total Hits: $hits',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                  fontFamily: 'Tuff',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }

  // --- Themed Generic Roll Dialog (Defense Save) ---
  void _showRollResult(
    BuildContext context,
    String rollType,
    int numberOfDice,
    int targetValue,
  ) {
    if (numberOfDice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Cannot roll: Dice count is zero.",
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
    final successes = rolls.where((r) => r >= targetValue).length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          title: Text(
            '$rollType Roll (Target $targetValue+)',
            style: TextStyle(color: _primaryText, fontFamily: 'Tuff'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rolled $numberOfDice D6:',
                style: TextStyle(color: _secondaryText, fontFamily: 'Garamond'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: rolls
                    .map(
                      (roll) => Chip(
                        label: Text(
                          roll.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        backgroundColor: roll >= targetValue
                            ? _accentColor
                            : Colors.red.shade400,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 15),
              Text(
                'Total Successes: $successes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                  fontFamily: 'Tuff',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }

  // --- Themed Morale Roll Specific Logic ---
  void _showMoraleRollResult(
    BuildContext context,
    int moraleTarget, // This is the *adjusted* target
    army_data.UnitEntry unit,
    HomeViewModel viewModel,
  ) {
    // Morale roll is 2D6
    final roll1 = 1 + Random().nextInt(6);
    final roll2 = 1 + Random().nextInt(6);
    final rollTotal = roll1 + roll2;

    int damageTaken = 0;
    String resultMessage = '';
    Color resultColor;
    String resultTitle;

    if (rollTotal >= moraleTarget) {
      // Success
      resultTitle = 'Morale Check PASSED';
      resultColor = Colors.green.shade400;
      resultMessage = 'PASSED ($rollTotal vs $moraleTarget+). No damage taken.';
    } else {
      // Failure - Damage taken is Morale Target minus the roll total
      damageTaken = moraleTarget - rollTotal;
      damageTaken = max(0, damageTaken); // Prevent taking negative damage

      // Update the wounds in the ViewModel
      final newWounds = unit.currentWounds + damageTaken;
      viewModel.updateWounds(
        unit.unitName,
        attachmentName: unit.attachmentName,
        newWounds: newWounds,
      );

      resultTitle = 'Morale Check FAILED';
      resultColor = Colors.red.shade400;
      if (damageTaken > 0) {
        resultMessage =
            'FAILED ($rollTotal vs $moraleTarget+)! Unit takes $damageTaken wounds.';
      } else {
        resultMessage = 'FAILED, but no wounds were calculated to be taken.';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          title: Text(
            resultTitle,
            style: TextStyle(color: resultColor, fontFamily: 'Tuff'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                  fontFamily: 'Garamond',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      roll1.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      roll2.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Total Roll: $rollTotal (Target: $moraleTarget+)',
                style: TextStyle(fontSize: 16, color: _primaryText),
              ),
              if (damageTaken > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '(Wounds automatically applied to unit state)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.redAccent,
                      fontFamily: 'Garamond',
                    ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: _accentColor)),
            ),
          ],
        );
      },
    );
  }
}
