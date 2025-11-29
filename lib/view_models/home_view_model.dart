import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/repositories/Ability_Repository.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  final UnitRepository _repository;
  final AbilityRepository _abilityRepository;

  ListPa? _listPa;
  ListPa? get listPa => _listPa;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  final ValueNotifier<ListPa?> navigateToDetails = ValueNotifier(null);

  // New state for tracking specific ability usage (e.g., "Order:" abilities)
  // Key: Unique Unit Identifier, Value: Map<Ability Name, bool isUsed>
  final Map<String, Map<String, bool>> _abilityActivationState = {};

  // Helper to generate a unique key for unit state tracking
  String _unitIdentifier(UnitEntry unit) =>
      '${unit.unitName}|${unit.attachmentName ?? ''}';

  HomeViewModel({
    required UnitRepository repository,
    required AbilityRepository abilityRepository,
  }) : _repository = repository,
       _abilityRepository = abilityRepository;

  // --- Core State Management ---

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

  // --- ABILITY ACTIVATION TRACKING ---

  /// Checks if a specific ability on a unit has been activated this round.
  bool isAbilityUsed(UnitEntry unit, String abilityName) {
    final unitId = _unitIdentifier(unit);
    return _abilityActivationState[unitId]?[abilityName] ?? false;
  }

  /// Toggles the activation status of a specific ability on a unit.
  void toggleAbilityUsed(UnitEntry unit, String abilityName) {
    final unitId = _unitIdentifier(unit);

    // Initialize the unit's ability map if it doesn't exist
    _abilityActivationState.putIfAbsent(unitId, () => <String, bool>{});

    // Toggle the state
    final currentState = _abilityActivationState[unitId]![abilityName] ?? false;
    _abilityActivationState[unitId]![abilityName] = !currentState;

    if (kDebugMode) {
      print(
        'Toggled ability: "$abilityName" on unit ${unit.unitName} to ${!currentState}',
      );
    }

    notifyListeners();
  }

  // --- KEYWORD CHECKER (For Critical Blow, Precision, etc.) ---

  /// Checks if a unit (or its attachment) has a specific keyword/ability.
  bool hasKeyword(UnitEntry unit, String keyword) {
    bool checkData(ArmyUnitData? data) {
      if (data == null) return false;
      return data.abilities.any(
        (ability) => ability.name.toLowerCase().contains(keyword.toLowerCase()),
      );
    }

    return checkData(unit.unitDetails) || checkData(unit.attachmentDetails);
  }

  // --- ABILITY ENRICHMENT LOGIC (Delegated to Repository) ---

  Future<void> _enrichAbilitiesInList(ListPa list) async {
    // Helper function to enrich ArmyUnitData
    ArmyUnitData? _enrichData(ArmyUnitData? data) {
      if (data == null) return null;

      final List<Ability> enrichedAbilities = data.abilities.map((ability) {
        final String rawAbilityName = ability.name;

        // CRITICAL FIX: Delegate the lookup and normalization to the AbilityRepository.
        final String ruleText = _abilityRepository.getAbilityRule(
          rawAbilityName,
        );

        // Check if the rule was successfully found (i.e., not the error message)
        if (!ruleText.contains('Rule text unavailable')) {
          // The repository returns a single string with newlines (\n) for formatting.
          // Split it to match the model's List<String> effects property.
          final List<String> ruleEffects = ruleText.split('\n');

          // Use the found effects if they are valid
          if (ruleEffects.isNotEmpty) {
            return ability.copyWith(effects: ruleEffects);
          }
        }

        // If not found, return the original ability object (with original/default effects)
        return ability;
      }).toList();

      return data.copyWith(abilities: enrichedAbilities);
    }

    // Helper function to enrich a UnitEntry
    UnitEntry _enrichUnit(UnitEntry unit) {
      return unit.copyWith(
        unitDetails: _enrichData(unit.unitDetails),
        attachmentDetails: _enrichData(unit.attachmentDetails),
      );
    }

    // 1. Apply enrichment to all parts of the list
    final enrichedCommander = _enrichData(list.commanderDetails);
    final enrichedCombatUnits = list.combatUnits.map(_enrichUnit).toList();
    final enrichedNCUs = list.ncus.map(_enrichUnit).toList();

    // 2. Update the ViewModel's state with the new, enriched ListPa
    _listPa = list.copyWith(
      commanderDetails: enrichedCommander,
      combatUnits: enrichedCombatUnits,
      ncus: enrichedNCUs,
    );
  }

  // --- NEW METHOD TO RETRIEVE LATEST UNIT STATE (FIX) ---

  /// Retrieves the current, up-to-date state of a unit from the ViewModel's listPa.
  UnitEntry getUnitState(UnitEntry unit) {
    final result = _findUnitAndList(
      unitName: unit.unitName,
      attachmentName: unit.attachmentName,
    );

    if (result == null) {
      // Fallback: If the unit can't be found (e.g., list not loaded yet),
      // return the unit provided in the argument.
      return unit;
    }

    // Return the unit from the list in the ViewModel, which holds the latest state.
    return result.unitList[result.index];
  }

  // --- WOUND & TACTICAL STATE INITIALIZATION (Replaces _applyWoundCorrection) ---

  /// Initializes all units in the list by setting their current tracking state
  /// (wounds, activation, modifiers) to zero/default.
  ListPa _initializeUnitTacticalState(ListPa list) {
    // 1. Initialize Combat Units
    final List<UnitEntry> initializedCombatUnits = list.combatUnits.map((unit) {
      // Trust the unit's baseWounds property (e.g., 4 for monster).
      return unit.copyWith(
        currentWounds: 0,
        isActivated: false,
        attackModifier: 0,
        defenseModifier: 0,
        defenseDiceModifier: 0,
        moraleModifier: 0,
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
    int rankIndex = 0; // Default to Rank 3 strength (index 0)

    if (maxWounds == 12) {
      // FIX: Standard 12-Wound Rank Degradation (Infantry/Cavalry)
      // Rank index increases (power drops) every 4 wounds lost.
      final woundsLost = unit.currentWounds;

      // Calculated index assumes a full 3-rank system (0, 1, 2)
      // 0-3 lost -> index 0 (Rank 3 strength)
      // 4-7 lost -> index 1 (Rank 2 strength)
      // 8-11 lost -> index 2 (Rank 1 strength)
      int calculatedRankIndex = (woundsLost / 4).floor();

      // Clamp the calculated rank index to the size of the available dice array.
      // This automatically handles Cavalry units that only provide 2 ranks (max index 1).
      rankIndex = calculatedRankIndex.clamp(0, attackProfile.dice.length - 1);
    } else if (maxWounds > 1) {
      // Logic for other multi-wound units (Monsters, Solos, Non-Standard Cavalry)

      // We assume a simple half-wounds threshold if multiple ranks are available.
      if (attackProfile.dice.length > 1) {
        final halfWounds = maxWounds / 2;
        if (unit.currentWounds > halfWounds) {
          // Drop to the next rank (index 1) once half wounds are lost
          rankIndex = 1;
        }
      }
      // Clamp to ensure we don't exceed the provided dice array size
      rankIndex = rankIndex.clamp(0, attackProfile.dice.length - 1);
    } else {
      // Single wound unit (Monsters, Solos, etc. with baseWounds <= 1)
      rankIndex = 0;
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

  // --- NCU ABILITIES GETTER (For UI display) ---

  /// Retrieves and formats the rules/effects of the unit (NCU or Combat Unit)
  /// and its attachment for display.
  List<String> getUnitAbilities(UnitEntry unit) {
    final List<String> descriptions = [];

    void formatAbilities(ArmyUnitData? data) {
      if (data == null || data.abilities.isEmpty) return;

      data.abilities.forEach((ability) {
        final name = ability.name;

        // FIX: Removed the embedded usageStatus [CLICK TO USE] from the string.
        // The UI (UnitDetailsScreen) must now determine the status and
        // display the button/status text based on the clean ability name.

        // Join the effects list.
        final effect = ability.effects.join('\n');

        // Send a clean string to the UI
        descriptions.add('**$name**:\n$effect');
      });
    }

    // 1. Add the primary unit's abilities (relevant for NCUs and Combat Units)
    formatAbilities(unit.unitDetails);

    // 2. Add the attachment's abilities, if present
    formatAbilities(unit.attachmentDetails);

    return descriptions;
  }

  // --- IMAGE PATH GETTER ---

  /// Generates the local asset path for the unit's image based on its unique ID.
  String getUnitImagePath(ArmyUnitData? data, {required String type}) {
    if (data == null || data.id == null || data.id!.isEmpty) {
      return 'standees/placeholder_$type.jpg';
    }

    return 'standees/${data.id}.jpg';
  }

  // --- CORE LIST PARSING & LOADING ---

  Future<void> parseArmyList(String rawArmyListText) async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();
    _listPa = null; // Clear previous data

    try {
      // 1. CRITICAL: Ensure the ability cache is loaded and normalized first.
      await _abilityRepository.fetchAndCacheAllAbilityEffects();

      // 2. Call the repository to parse and fetch unit details (backend call)
      ListPa result = await _repository.parseListAndFetchDetails(
        rawArmyListText,
      );

      // 3. INITIALIZE TACTICAL STATE (applies default wounds/modifiers)
      ListPa initializedList = _initializeUnitTacticalState(result);

      // 4. Enrich abilities using the dedicated repository call
      await _enrichAbilitiesInList(initializedList);

      // 5. Data is ready, trigger navigation
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
    // Max wounds depends on unitDetails.baseWounds (which should now be correctly loaded)
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

  /// Resets the activation status for all units and ability usage for the start of a new round.
  void resetAllActivations() {
    if (_listPa == null) return;

    // CRITICAL: Clear all ability usage tracking
    _abilityActivationState.clear();

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
