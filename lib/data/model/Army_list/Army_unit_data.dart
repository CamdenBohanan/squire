import 'dart:convert';
import 'package:flutter/foundation.dart';

class AttackProfile {
  final String name;
  final String type; // 'melee' or 'long' (range)
  final int hit; // To Hit value
  final List<int> dice; // Array of dice counts [Rank 3, Rank 2, Rank 1]

  AttackProfile({
    required this.name,
    required this.type,
    required this.hit,
    required this.dice,
  });

  factory AttackProfile.fromJson(Map<String, dynamic> json) {
    return AttackProfile(
      name: json['name'] ?? 'Unknown Attack',
      type: json['type'] ?? 'melee',
      hit: json['hit'] ?? 4,
      // Ensure dice is parsed as a List<int>
      dice: (json['dice'] is List)
          ? List<int>.from(json['dice'].whereType<int>())
          : [],
    );
  }
}

// ----------------------------------------------------------------------
// 1. ArmyUnitData: Unit details fetched from the backend/API
// ----------------------------------------------------------------------
class ArmyUnitData {
  // --- Core Identity Fields (From MongoDB) ---
  final String id;
  final String? name;
  final String? title;
  final String? role;
  final String? faction;
  final int? points;

  // --- Combat Unit Specific Fields ---
  final int? defense; // Now an int, e.g., 4
  final int? morale; // Now an int, e.g., 7
  final int?
  baseWounds; // Maps to JSON 'wounds' field (e.g., 12 for Infantry/Cavalry)
  final int? speed;
  final String? tray; // Maps to JSON 'tray'

  // --- Attack details (Now a list of profiles) ---
  final List<AttackProfile> attacks;

  // --- Ability/Rule Fields ---
  final Map<String, String> abilities;

  // --- CRITICAL ADDITION for UI: Fluff/Lore Text ---
  final String? fluffText;

  // --- Constructor ---
  ArmyUnitData({
    required this.id,
    this.name,
    this.title,
    this.role,
    this.faction,
    this.points,
    this.defense,
    this.morale,
    this.baseWounds,
    this.speed,
    this.tray,
    required this.attacks, // Updated to List<AttackProfile>
    required this.abilities,
    this.fluffText, // Added fluffText to constructor
  });

  // --- Factory Constructor: fromJson ---
  factory ArmyUnitData.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseAbilities(dynamic jsonValue) {
      if (jsonValue == null) return {};
      if (jsonValue is List) {
        final Map<String, String> result = {};
        for (final item in jsonValue) {
          if (item is Map<String, dynamic> &&
              item.containsKey('name') &&
              item.containsKey('description')) {
            result[item['name'].toString()] = item['description'].toString();
          }
        }
        return result;
      }
      if (jsonValue is Map) {
        return jsonValue.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      return {};
    }

    // New attack parsing logic
    List<AttackProfile> parseAttacks(dynamic jsonValue) {
      if (jsonValue == null || jsonValue is! List) return [];
      return (jsonValue as List)
          .map((item) => AttackProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // *** CRITICAL FIX: Use the 'id' field as specified by the user ***
    String extractedId = json['id']?.toString() ?? '0';

    int? safeInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    String? safeString(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    final tray = safeString(json['tray'])?.toLowerCase();

    // LOGIC UPDATE: Default to 12 wounds if infantry OR cavalry (as requested)
    final int? defaultWounds = (tray == 'infantry' || tray == 'cavalry')
        ? 12
        : null;

    return ArmyUnitData(
      id: extractedId,
      name: safeString(json['name']),
      title: safeString(json['title']),
      role: safeString(json['role']) ?? 'unit',
      faction: safeString(json['faction']) ?? 'Neutral',
      points: safeInt(json['points']) ?? safeInt(json['cost']),
      // Defense and Morale are now integers
      defense: safeInt(json['defense']),
      morale: safeInt(json['morale']),
      baseWounds:
          safeInt(json['wounds']) ?? defaultWounds, // Applies default logic
      speed: safeInt(json['speed']),
      tray: safeString(json['tray']),

      // Use new attack parser
      attacks: parseAttacks(json['attacks']),

      abilities: parseAbilities(json['abilities']),

      // CRITICAL: Safely extract fluff/lore text from the JSON
      fluffText: safeString(json['fluff']) ?? safeString(json['lore']),
    );
  }

  // --- NEW copyWith Method ---
  ArmyUnitData copyWith({
    String? id,
    String? name,
    String? title,
    String? role,
    String? faction,
    int? points,
    int? defense,
    int? morale,
    int? baseWounds,
    int? speed,
    String? tray,
    List<AttackProfile>? attacks,
    Map<String, String>? abilities,
    String? fluffText, // Added fluffText to copyWith
  }) {
    return ArmyUnitData(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      role: role ?? this.role,
      faction: faction ?? this.faction,
      points: points ?? this.points,
      defense: defense ?? this.defense,
      morale: morale ?? this.morale,
      baseWounds: baseWounds ?? this.baseWounds,
      speed: speed ?? this.speed,
      tray: tray ?? this.tray,
      attacks: attacks ?? this.attacks,
      abilities: abilities ?? this.abilities,
      fluffText: fluffText ?? this.fluffText, // Update
    );
  }
}

// ----------------------------------------------------------------------
// 2. UnitEntry (Tracker State)
// ----------------------------------------------------------------------
class UnitEntry {
  // Core Identifiers
  final String unitName;
  final String? attachmentName;

  // Cost/Points (Used by the Parser)
  final int unitCost;
  final int? attachmentCost; // Cost of the attachment

  // Local Tactical State (Managed by ViewModel)
  final int currentWounds; // Tracks current wounds taken
  final bool isActivated; // Tracks activation status
  final int
  currentModifier; // Tracks general modifiers (DEPRECATED - now using specific below)

  // NEW SPECIFIC MODIFIERS
  final int
  attackModifier; // Modifier applied to Hit roll target (e.g., -1 for cover, +1 for flank)
  final int
  defenseModifier; // Modifier applied to Save roll target (e.g., +1 for panic)
  final int
  moraleModifier; // Modifier applied to Morale roll target (e.g., -1 for terror)
  final int
  defenseDiceModifier; // NEW: Modifier applied to the number of defense dice rolled

  // Enriched Detail Data (Fetched by Repository)
  final ArmyUnitData? unitDetails;
  final ArmyUnitData? attachmentDetails;

  // --- Primary Constructor ---
  UnitEntry({
    required this.unitName,
    this.attachmentName,
    this.unitCost = 0,
    this.attachmentCost,
    this.currentWounds = 0,
    this.isActivated = false,
    this.currentModifier = 0,
    this.attackModifier = 0,
    this.defenseModifier = 0,
    this.moraleModifier = 0,
    this.defenseDiceModifier = 0, // Initialize new field
    this.unitDetails,
    this.attachmentDetails,
  });

  // --- NAMED CONSTRUCTOR for Combat Units (used by the parser) ---
  UnitEntry.combatUnit({
    required String unitName,
    required int unitCost,
    String? attachmentName,
    int? attachmentCost,
  }) : this(
         unitName: unitName,
         unitCost: unitCost,
         attachmentName: attachmentName,
         attachmentCost: attachmentCost,
         currentWounds: 0,
         isActivated: false,
         attackModifier: 0,
         defenseModifier: 0,
         moraleModifier: 0,
         defenseDiceModifier: 0,
       );

  // --- NAMED CONSTRUCTOR for NCUs (used by the parser) ---
  UnitEntry.ncu({required String unitName, required int unitCost})
    : this(
        unitName: unitName,
        unitCost: unitCost,
        currentWounds: 0,
        isActivated: false,
        attackModifier: 0,
        defenseModifier: 0,
        moraleModifier: 0,
        defenseDiceModifier: 0,
      );

  // --- copyWith Method ---
  UnitEntry copyWith({
    String? unitName,
    String? attachmentName,
    int? unitCost,
    int? attachmentCost,
    int? currentWounds,
    bool? isActivated,
    int? currentModifier,
    int? attackModifier,
    int? defenseModifier,
    int? moraleModifier,
    int? defenseDiceModifier, // Added new field
    ArmyUnitData? unitDetails,
    ArmyUnitData? attachmentDetails,
  }) {
    return UnitEntry(
      unitName: unitName ?? this.unitName,
      attachmentName: attachmentName ?? this.attachmentName,
      unitCost: unitCost ?? this.unitCost,
      attachmentCost: attachmentCost ?? this.attachmentCost,
      currentWounds: currentWounds ?? this.currentWounds,
      isActivated: isActivated ?? this.isActivated,
      currentModifier: currentModifier ?? this.currentModifier,
      attackModifier: attackModifier ?? this.attackModifier,
      defenseModifier: defenseModifier ?? this.defenseModifier,
      moraleModifier: moraleModifier ?? this.moraleModifier,
      defenseDiceModifier:
          defenseDiceModifier ?? this.defenseDiceModifier, // Update
      unitDetails: unitDetails ?? this.unitDetails,
      attachmentDetails: attachmentDetails ?? this.attachmentDetails,
    );
  }
}

// ----------------------------------------------------------------------
// 3. ListPa: Represents the entire parsed army list structure.
// ----------------------------------------------------------------------
class ListPa {
  final String listId;
  final String faction;
  final String commanderName;
  final ArmyUnitData? commanderDetails;

  final int totalPoints;
  final int totalActivations;
  final List<UnitEntry> combatUnits;
  final List<UnitEntry> ncus;

  ListPa({
    this.listId = 'local_list',
    required this.faction,
    required this.commanderName,
    this.commanderDetails,
    required this.combatUnits,
    required this.ncus,
    this.totalPoints = 0,
    this.totalActivations = 0,
  });

  // The copyWith method MUST include all fields.
  ListPa copyWith({
    String? listId,
    String? faction,
    String? commanderName,
    ArmyUnitData? commanderDetails,
    int? totalPoints,
    int? totalActivations,
    List<UnitEntry>? combatUnits,
    List<UnitEntry>? ncus,
  }) {
    return ListPa(
      listId: listId ?? this.listId,
      faction: faction ?? this.faction,
      commanderName: commanderName ?? this.commanderName,
      commanderDetails: commanderDetails ?? this.commanderDetails,
      totalPoints: totalPoints ?? this.totalPoints,
      totalActivations: totalActivations ?? this.totalActivations,
      combatUnits: combatUnits ?? this.combatUnits,
      ncus: ncus ?? this.ncus,
    );
  }
}
