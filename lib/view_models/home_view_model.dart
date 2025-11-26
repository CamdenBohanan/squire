import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart'; // Use the singular, correct model file
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  final UnitRepository _repository;

  ListPa? _listPa;
  ListPa? get listPa => _listPa;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  final ValueNotifier<ListPa?> navigateToDetails = ValueNotifier(null);

  HomeViewModel({required UnitRepository repository})
    : _repository = repository;

  // --- Helper Methods ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void loadArmyList(ListPa newList) {
    // If loading from a pre-parsed source, ensure tactical state is initialized
    _listPa = _initializeUnitTacticalState(newList);
    notifyListeners();
  }

  // Helper function to find the unit and the list index
  ({List<UnitEntry> unitList, int index})? _findUnitAndList({
    required String unitName,
    String? attachmentName,
  }) {
    if (_listPa == null) return null;

    // 1. Search Combat Units
    int cuIndex = _listPa!.combatUnits.indexWhere(
      (u) => u.unitName == unitName && u.attachmentName == attachmentName,
    );
    if (cuIndex != -1) {
      return (unitList: _listPa!.combatUnits, index: cuIndex);
    }

    // 2. Search NCUs
    int ncuIndex = _listPa!.ncus.indexWhere(
      (u) => u.unitName == unitName && u.attachmentName == attachmentName,
    );
    if (ncuIndex != -1) {
      return (unitList: _listPa!.ncus, index: ncuIndex);
    }

    return null;
  }

  // --- WOUND & TACTICAL STATE INITIALIZATION (Replaces _applyWoundCorrection) ---

  /// Initializes all units in the list by setting their current tracking state
  /// (wounds, activation, modifiers) to zero/default.
  ListPa _initializeUnitTacticalState(ListPa list) {
    // 1. Initialize Combat Units
    final List<UnitEntry> initializedCombatUnits = list.combatUnits.map((unit) {
      // FIX: DO NOT apply the heuristic that forces wounds to 12.
      // Trust the unit's baseWounds property (e.g., 4 for a monster).
      return unit.copyWith(
        currentWounds: 0,
        isActivated: false,
        attackModifier: 0,
        defenseModifier: 0,
        defenseDiceModifier: 0,
        moraleModifier: 0,
        // The UnitDetails model remains unchanged, preserving the correct baseWounds.
      );
    }).toList();

    // 2. Initialize NCUs
    final List<UnitEntry> initializedNCUs = list.ncus.map((unit) {
      return unit.copyWith(
        currentWounds: 0, // NCUs track wounds too, typically 1 or 0
        isActivated: false,
        // NCUs don't typically have modifiers, but setting them to 0 is safe
        attackModifier: 0,
        defenseModifier: 0,
        defenseDiceModifier: 0,
        moraleModifier: 0,
      );
    }).toList();

    // Return a new ListPa with the fully initialized units lists
    return list.copyWith(
      combatUnits: initializedCombatUnits,
      ncus: initializedNCUs,
    );
  }

  // --- CORE NEW LOGIC: CALCULATE ATTACK DICE BASED ON WOUNDS/RANK ---

  /// Determines the current dice count for a given attack profile based on unit wounds.
  int getAttackDiceForUnit(UnitEntry unit, String attackType) {
    final details = unit.unitDetails;
    if (details == null) return 0;

    // Use the correctly loaded baseWounds (e.g., 4 for monster, 12 for infantry)
    final maxWounds = details.baseWounds ?? 12;
    final woundsRemaining = maxWounds - unit.currentWounds;

    // Check for destroyed unit first
    if (woundsRemaining <= 0) {
      return 0;
    }

    // 1. Find the specific attack profile (melee or long)
    final attackProfile = details.attacks.firstWhere(
      (a) => a.type == attackType,
      orElse: () => AttackProfile(name: '', type: '', hit: 0, dice: []),
    );

    if (attackProfile.dice.isEmpty) return 0;

    // 2. Determine the current Rank based on Wounds Taken
    int rankIndex = 0; // Default to Rank 3 strength (0 wounds taken)

    if (maxWounds >= 12) {
      // Logic for standard 12-wound units (Infantry/Cavalry)
      final isCavalry = details.tray?.toLowerCase() == 'cavalry';
      // Wounds remaining threshold to drop to Rank 2 (index 1)
      final rank2Threshold = isCavalry
          ? 6
          : 8; // 6 if Cav (6 wounds lost), 8 if Inf (4 wounds lost)
      // Wounds remaining threshold to drop to Rank 1 (index 2)
      final rank1Threshold = isCavalry
          ? 0
          : 4; // 0 if Cav (12 wounds lost), 4 if Inf (8 wounds lost)

      if (woundsRemaining <= rank2Threshold &&
          woundsRemaining > rank1Threshold) {
        rankIndex = 1; // Rank 2 strength
      } else if (woundsRemaining <= rank1Threshold && woundsRemaining >= 1) {
        rankIndex = 2; // Rank 1 strength
      }
    } else {
      // Logic for low-wound units (Monsters, Solo units, etc. - e.g. 4 wounds)
      // If the unit has a fixed number of wounds (like 4), it typically doesn't degrade.
      // We assume it uses the maximum dice count (index 0) until destroyed.
      rankIndex = 0;
    }

    // Safety check: ensure the index is within the bounds of the dice array
    if (rankIndex >= attackProfile.dice.length) {
      // For low-wound units that only have one dice entry, this falls back to the first.
      rankIndex = attackProfile.dice.length - 1;
    }

    // 3. Return the calculated dice count for the current rank
    return attackProfile.dice[rankIndex];
  }

  /// Getter for the Defense Save value, adjusted by modifier
  int getDefenseSaveTarget(UnitEntry unit) {
    final details = unit.unitDetails;
    if (details == null) return 4;

    final baseSave = details.defense ?? 4;
    // Modifiers affect the target roll (e.g., +1 modifier makes a 4+ save a 5+ save)
    final finalTarget = baseSave + unit.defenseModifier;

    // Save target must be clamped between 2 and 6 (2+ to 6+)
    return finalTarget.clamp(2, 6);
  }

  /// Getter for the Morale target value, adjusted by modifier
  int getMoraleTarget(UnitEntry unit) {
    final details = unit.unitDetails;
    if (details == null) return 7;

    final baseMorale = details.morale ?? 7;
    // Modifiers affect the target roll (e.g., -1 modifier makes a 7+ check a 6+ check)
    final finalTarget = baseMorale + unit.moraleModifier;

    // Morale target must be between 2 and 12
    return finalTarget.clamp(2, 12);
  }

  /// Getter for To-Hit value for a specific attack type, adjusted by modifier
  int getToHitTarget(UnitEntry unit, String attackType) {
    final details = unit.unitDetails;
    if (details == null) return 4;

    final profile = details.attacks.firstWhere(
      (a) => a.type == attackType,
      orElse: () => AttackProfile(name: '', type: '', hit: 4, dice: []),
    );

    final baseHit = profile.hit;

    // Modifiers affect the target roll (e.g., +1 modifier makes a 3+ hit a 4+ hit)
    final finalTarget = baseHit + unit.attackModifier;

    // Hit target must be clamped between 2 and 6 (2+ to 6+)
    return finalTarget.clamp(2, 6);
  }

  /// Getter for the Defense Dice count, adjusted by modifier
  int getDefenseDiceCount(UnitEntry unit) {
    // Base defense dice for most units is 6.
    const baseDice = 6;
    // Apply the new modifier, clamping the result to a sensible range (min 1 dice)
    return (baseDice + unit.defenseDiceModifier).clamp(1, 10);
  }

  // --- NCU ABILITIES GETTER ---

  /// Retrieves and formats the rules/effects of the unit (NCU or Combat Unit)
  /// and its attachment for display.
  List<String> getUnitAbilities(UnitEntry unit) {
    final List<String> descriptions = [];

    void formatAbilities(ArmyUnitData? data) {
      if (data == null || data.abilities.isEmpty) return;

      // Format each ability name and its effect into a single string
      data.abilities.forEach((name, effect) {
        descriptions.add('**$name**: $effect');
      });
    }

    // 1. Add the primary unit's abilities (relevant for NCUs and Combat Units)
    formatAbilities(unit.unitDetails);

    // 2. Add the attachment's abilities, if present
    formatAbilities(unit.attachmentDetails);

    return descriptions;
  }

  // --- CORE LIST PARSING & LOADING ---

  Future<void> parseArmyList(String rawArmyListText) async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();
    _listPa = null; // Clear previous data

    try {
      // 1. Call the repository to parse and fetch details
      ListPa result = await _repository.parseListAndFetchDetails(
        rawArmyListText,
      );

      // 2. INITIALIZE TACTICAL STATE (removes the incorrect 12-wound fix)
      _listPa = _initializeUnitTacticalState(result);

      // 3. Data is ready, trigger navigation
      if (_listPa != null) {
        navigateToDetails.value = _listPa;
      }
    } catch (e) {
      if (kDebugMode) print('ViewModel Catch: Failed to process list: $e');
      _setErrorMessage(
        "Processing Error: Could not process list details. Error: $e",
      );
      _listPa = null;
    } finally {
      _setLoading(false);
    }
  }

  String getUnitFluffText(ArmyUnitData? unitData) {
    if (unitData == null) {
      return 'Unit details not found. No lore available.';
    }

    final fluff = unitData.fluffText?.trim();

    if (fluff?.isNotEmpty == true) {
      return fluff!;
    }

    return 'No lore or background available for this unit.';
  }

  /// Generic update function that finds a unit by name/attachment and updates its tactical state.
  void _updateUnitState(
    String unitName, {
    String? attachmentName,
    int? currentWounds,
    bool? isActivated,
    int? attackModifier,
    int? defenseModifier,
    int? moraleModifier,
    int? defenseDiceModifier,
  }) {
    final result = _findUnitAndList(
      unitName: unitName,
      attachmentName: attachmentName,
    );

    if (result == null) {
      debugPrint(
        'Error: Unit $unitName (Attachment: $attachmentName) not found for state update.',
      );
      return;
    }

    final list = result.unitList;
    final index = result.index;

    final unitToUpdate = list[index];

    // --- CRITICAL FIX: Clamp all incoming or default modifiers between -5 and 5 ---
    const int minCap = -5;
    const int maxCap = 5;

    final clampedAttack = (attackModifier ?? unitToUpdate.attackModifier).clamp(
      minCap,
      maxCap,
    );
    final clampedDefense = (defenseModifier ?? unitToUpdate.defenseModifier)
        .clamp(minCap, maxCap);
    final clampedMorale = (moraleModifier ?? unitToUpdate.moraleModifier).clamp(
      minCap,
      maxCap,
    );
    final clampedDefenseDice =
        (defenseDiceModifier ?? unitToUpdate.defenseDiceModifier).clamp(
          minCap,
          maxCap,
        );

    // --- WOUND CLAMPING FIX ---
    // If we're updating wounds, ensure they don't exceed max wounds (which is unitDetails.baseWounds)
    final maxWounds = unitToUpdate.unitDetails?.baseWounds ?? 12;
    int wounds = currentWounds ?? unitToUpdate.currentWounds;
    wounds = wounds.clamp(0, maxWounds);

    final updatedUnit = unitToUpdate.copyWith(
      currentWounds: wounds,
      isActivated: isActivated ?? unitToUpdate.isActivated,
      attackModifier: clampedAttack,
      defenseModifier: clampedDefense,
      moraleModifier: clampedMorale,
      defenseDiceModifier: clampedDefenseDice,
    );

    // Create a new list with the updated unit (for immutability)
    final newList = List<UnitEntry>.from(list);
    newList[index] = updatedUnit;

    // Determine if we update combatUnits or ncus
    if (list == _listPa!.combatUnits) {
      _listPa = _listPa!.copyWith(combatUnits: newList);
    } else {
      _listPa = _listPa!.copyWith(ncus: newList);
    }

    notifyListeners();
  }

  /// Updates the wound counter for a Combat Unit.
  void updateWounds(
    String unitName, {
    String? attachmentName,
    required int newWounds,
  }) {
    _updateUnitState(
      unitName,
      currentWounds: newWounds,
      attachmentName: attachmentName,
    );
  }

  /// Toggles the activation status for any unit (Combat or NCU).
  void toggleActivation(String unitName, {String? attachmentName}) {
    final result = _findUnitAndList(
      unitName: unitName,
      attachmentName: attachmentName,
    );

    if (result == null) {
      debugPrint(
        'Error: Unit $unitName (Attachment: $attachmentName) not found for activation toggle.',
      );
      return;
    }

    // Use the unit found by _findUnitAndList to get the current state
    final targetUnit = result.unitList[result.index];

    _updateUnitState(
      unitName,
      attachmentName: targetUnit.attachmentName,
      isActivated: !targetUnit.isActivated,
    );
  }

  // --- Modifier Updaters (These now use the clamped _updateUnitState) ---

  void updateAttackModifier(
    String unitName, {
    String? attachmentName,
    required int modifier,
  }) {
    _updateUnitState(
      unitName,
      attachmentName: attachmentName,
      attackModifier: modifier,
    );
  }

  void updateDefenseModifier(
    String unitName, {
    String? attachmentName,
    required int modifier,
  }) {
    _updateUnitState(
      unitName,
      attachmentName: attachmentName,
      defenseModifier: modifier,
    );
  }

  void updateMoraleModifier(
    String unitName, {
    String? attachmentName,
    required int modifier,
  }) {
    _updateUnitState(
      unitName,
      attachmentName: attachmentName,
      moraleModifier: modifier,
    );
  }

  /// Updates the defense dice modifier for a unit.
  void updateDefenseDiceModifier(
    String unitName, {
    String? attachmentName,
    required int modifier,
  }) {
    _updateUnitState(
      unitName,
      attachmentName: attachmentName,
      defenseDiceModifier: modifier,
    );
  }

  /// Resets the activation status for all units on the list.
  void resetAllActivations() {
    if (_listPa == null) return;

    List<UnitEntry> resetList(List<UnitEntry> units) {
      return units.map((unit) {
        return unit.copyWith(
          isActivated: false,
          currentWounds: 0,
          attackModifier: 0,
          defenseModifier: 0,
          defenseDiceModifier: 0,
          moraleModifier: 0,
        );
      }).toList();
    }

    _listPa = _listPa!.copyWith(
      combatUnits: resetList(_listPa!.combatUnits),
      ncus: resetList(_listPa!.ncus),
    );

    notifyListeners();
  }
}
