import 'dart:convert';
import 'package:flutter/foundation.dart';

// --- Static Game Data Models ---

/// Represents a single attack profile for a unit.
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
      dice: (json['dice'] is List)
          ? List<int>.from(json['dice'].whereType<int>())
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'hit': hit,
    'dice': dice,
  };
}

/// Represents a unit or NCU ability.
class Ability {
  final String name;
  final List<String> effects; // The effect is a list of strings

  Ability({required this.name, required this.effects});

  // FIX: Check for 'effects' (plural) as well as 'effect' (singular) for resilience.
  factory Ability.fromJson(Map<String, dynamic> json) {
    final dynamic effectsValue =
        json['effects'] ?? json['effect']; // Check both keys

    return Ability(
      name: json['name'] as String? ?? 'Unknown Ability',
      effects: (effectsValue is List)
          ? List<String>.from(effectsValue)
          : [if (effectsValue != null) effectsValue.toString()],
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'effect': effects};

  // --- NEW: copyWith Method for easier updates ---
  Ability copyWith({String? name, List<String>? effects}) {
    return Ability(name: name ?? this.name, effects: effects ?? this.effects);
  }
}

// ----------------------------------------------------------------------
// 1. ArmyUnitData: Unit details fetched from the backend/API
// ----------------------------------------------------------------------
class ArmyUnitData {
  // --- Core Identity Fields ---
  final String id;
  final String name; // Made non-nullable as it's critical for the repository
  final String? title;
  final String? role;
  final String faction; // Made non-nullable, essential for API calls
  final int? points;
  final List<Ability> abilities;

  // --- Combat Unit Specific Fields ---
  final int? defense;
  final int? morale;
  final int? baseWounds; // This will now hold the total (e.g., 12)
  final int? speed;
  final String? tray;

  // --- Attack details ---
  final List<AttackProfile> attacks;

  // --- Fluff/Lore Text ---
  final String? fluffText;

  // --- Constructor ---
  ArmyUnitData({
    required this.id,
    required this.name, // Required
    required this.faction, // Required
    this.title,
    this.role,
    this.points,
    this.defense,
    this.morale,
    this.baseWounds,
    this.speed,
    this.tray,
    this.attacks = const [], // Defaulted to empty list
    this.abilities = const [], // Defaulted to empty list
    this.fluffText,
  });

  // --- Factory Constructor: fromJson ---
  factory ArmyUnitData.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse dynamic values to int
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

    // --- Ability and Attack Parsing (Unchanged) ---
    List<Ability> parseAbilities(dynamic jsonValue) {
      if (jsonValue == null || jsonValue is! List) return [];

      return (jsonValue as List)
          .map((item) {
            if (item is Map<String, dynamic>) {
              return Ability.fromJson(item);
            } else if (item is String) {
              return Ability(name: item, effects: [item]);
            }
            return null;
          })
          .whereType<Ability>()
          .toList();
    }

    List<AttackProfile> parseAttacks(dynamic jsonValue) {
      if (jsonValue == null || jsonValue is! List) return [];
      return (jsonValue as List)
          .map((item) => AttackProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    // --- End Parsing Helpers ---

    // --- Core Data Extraction ---
    String extractedId = json['id']?.toString() ?? '0';
    String parsedName =
        safeString(json['name']) ?? safeString(json['id']) ?? 'Unknown Unit';
    String parsedFaction = safeString(json['faction']) ?? 'Neutral';
    String? parsedTray = safeString(json['tray'])?.toLowerCase();
    String? parsedRole = safeString(json['role'])?.toLowerCase();

    String? parsedFluff = (json['fluff'] is Map)
        ? safeString((json['fluff'] as Map<String, dynamic>)['lore'])
        : safeString(json['fluff']);

    // Get the raw 'wounds' value from the JSON. This is often wounds-per-rank (e.g., 3).
    final int? rawWoundsPerRank =
        safeInt(json['wounds']) ?? safeInt(json['baseWounds']);

    // --- CRITICAL WOUNDS FIX LOGIC ---
    int? calculateTotalWounds(int? rawWounds, String? tray) {
      if (rawWounds == null || rawWounds <= 0) return null;

      // ASOIAF TMG Rule: Combat units have wounds-per-rank, which must be multiplied by 4.
      // We look for Infantry/Cavalry units with a low raw wound count (1, 2, or 3).
      if (rawWounds <= 3 && (tray == 'infantry' || tray == 'cavalry')) {
        if (kDebugMode)
          print(
            'Calculated combat unit wounds: $rawWounds * 4 = ${rawWounds * 4}',
          );
        return rawWounds * 4;
      }

      // For Solos, NCUs, Monsters (where the raw value is the total), use the raw value.
      if (kDebugMode)
        print('Using raw wounds value: $rawWounds for tray type: $tray');
      return rawWounds;
    }

    final int? calculatedWounds = calculateTotalWounds(
      rawWoundsPerRank,
      parsedTray,
    );

    // --- FINAL RESILIENCE CHECK ---
    int? finalBaseWounds = calculatedWounds;

    // If the wounds calculation resulted in null/0, but the unit metadata suggests it's a combat unit,
    // we force the default of 12. This catches JSON entries where 'wounds' or 'tray' might be missing.
    final bool isCombatUnit =
        (parsedTray == 'infantry' || parsedTray == 'cavalry') ||
        (parsedRole == 'unit' && parsedTray != 'ncu');

    if ((finalBaseWounds == null || finalBaseWounds == 0)) {
      if (isCombatUnit) {
        finalBaseWounds = 12;
        if (kDebugMode)
          print('FORCED baseWounds to 12 (Default Combat Unit Fallback).');
      } else if (parsedTray == 'ncu' || parsedRole == 'ncu') {
        finalBaseWounds = 1; // NCU fallback
      }
    }
    // --- END FINAL RESILIENCE CHECK ---

    return ArmyUnitData(
      id: extractedId,
      name: parsedName, // Safely parsed, now non-nullable
      faction: parsedFaction, // Safely parsed, now non-nullable
      title: safeString(json['title']),
      role: parsedRole ?? 'unit',
      points: safeInt(json['points']) ?? safeInt(json['cost']),
      defense: safeInt(json['defense']),
      morale: safeInt(json['morale']),
      baseWounds:
          finalBaseWounds, // <-- This should now reliably be 12 for Infantry
      speed: safeInt(json['speed']),
      tray: parsedTray,
      attacks: parseAttacks(json['attacks']),
      abilities: parseAbilities(json['abilities']),
      fluffText: parsedFluff ?? safeString(json['lore']),
    );
  }

  // --- toJson Method ---
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'title': title,
    'role': role,
    'faction': faction,
    'points': points,
    'defense': defense,
    'morale': morale,
    // Use baseWounds (total) for saving/transfer, not raw wounds-per-rank
    'baseWounds': baseWounds,
    'speed': speed,
    'tray': tray,
    'attacks': attacks.map((a) => a.toJson()).toList(),
    'abilities': abilities.map((a) => a.toJson()).toList(),
    'fluffText': fluffText,
  };

  // --- copyWith Method ---
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
    List<Ability>? abilities,
    String? fluffText,
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
      fluffText: fluffText ?? this.fluffText,
    );
  }
}

// ----------------------------------------------------------------------
// 2. UnitEntry (Tracker State) - Kept unchanged
// ----------------------------------------------------------------------
class UnitEntry {
  // Core Identifiers (Made non-nullable, relying on Parser/Repository to fill)
  final String unitName;
  final String? attachmentName;

  // Cost/Points (Used by the Parser)
  final int unitCost;
  final int attachmentCost;

  // Local Tactical State (Managed by ViewModel)
  final int currentWounds;
  final bool isActivated;
  final int attackModifier;
  final int defenseModifier;
  final int moraleModifier;
  final int defenseDiceModifier;

  // Enriched Detail Data (Fetched by Repository)
  final ArmyUnitData? unitDetails;
  final ArmyUnitData? attachmentDetails;

  // --- Primary Constructor (Sets all necessary defaults) ---
  UnitEntry({
    required this.unitName,
    this.attachmentName,
    this.unitCost = 0,
    this.attachmentCost = 0, // Defaulted to 0
    this.currentWounds = 0,
    this.isActivated = false,
    this.attackModifier = 0,
    this.defenseModifier = 0,
    this.moraleModifier = 0,
    this.defenseDiceModifier = 0,
    this.unitDetails,
    this.attachmentDetails,
  });

  // --- NAMED CONSTRUCTOR for Combat Units (used by the parser) ---
  // Cleanly delegates to the primary constructor and relies on its defaults
  UnitEntry.combatUnit({
    required String unitName,
    required int unitCost,
    String? attachmentName,
    int? attachmentCost,
  }) : this(
         unitName: unitName,
         unitCost: unitCost,
         attachmentName: attachmentName,
         attachmentCost: attachmentCost ?? 0,
       );

  // --- NAMED CONSTRUCTOR for NCUs (used by the parser) ---
  // Cleanly delegates to the primary constructor and relies on its defaults
  UnitEntry.ncu({required String unitName, required int unitCost})
    : this(unitName: unitName, unitCost: unitCost);

  // --- Factory Constructor: fromJson ---
  factory UnitEntry.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    ArmyUnitData? parseDetails(dynamic detailsJson) {
      if (detailsJson != null && detailsJson is Map<String, dynamic>) {
        return ArmyUnitData.fromJson(detailsJson);
      }
      return null;
    }

    return UnitEntry(
      unitName: json['unitName'] as String? ?? 'Unknown Unit',
      attachmentName: json['attachmentName'] as String?,
      unitCost: safeInt(json['unitCost']),
      attachmentCost: safeInt(json['attachmentCost']),
      currentWounds: safeInt(json['currentWounds']),
      isActivated: json['isActivated'] as bool? ?? false,
      attackModifier: safeInt(json['attackModifier']),
      defenseModifier: safeInt(json['defenseModifier']),
      moraleModifier: safeInt(json['moraleModifier']),
      defenseDiceModifier: safeInt(json['defenseDiceModifier']),
      unitDetails: parseDetails(json['unitDetails']),
      attachmentDetails: parseDetails(json['attachmentDetails']),
    );
  }

  // --- toJson Method ---
  Map<String, dynamic> toJson() => {
    'unitName': unitName,
    'attachmentName': attachmentName,
    'unitCost': unitCost,
    'attachmentCost': attachmentCost,
    'currentWounds': currentWounds,
    'isActivated': isActivated,
    'attackModifier': attackModifier,
    'defenseModifier': defenseModifier,
    'moraleModifier': moraleModifier,
    'defenseDiceModifier': defenseDiceModifier,
    'unitDetails': unitDetails?.toJson(),
    'attachmentDetails': attachmentDetails?.toJson(),
  };

  // --- copyWith Method ---
  UnitEntry copyWith({
    String? unitName,
    String? attachmentName,
    int? unitCost,
    int? attachmentCost,
    int? currentWounds,
    bool? isActivated,
    int? attackModifier,
    int? defenseModifier,
    int? moraleModifier,
    int? defenseDiceModifier,
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
      attackModifier: attackModifier ?? this.attackModifier,
      defenseModifier: defenseModifier ?? this.defenseModifier,
      moraleModifier: moraleModifier ?? this.moraleModifier,
      defenseDiceModifier: defenseDiceModifier ?? this.defenseDiceModifier,
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

  // --- toJson Method ---
  Map<String, dynamic> toJson() => {
    'listId': listId,
    'faction': faction,
    'commanderName': commanderName,
    'commanderDetails': commanderDetails?.toJson(),
    'totalPoints': totalPoints,
    'totalActivations': totalActivations,
    'combatUnits': combatUnits.map((u) => u.toJson()).toList(),
    'ncus': ncus.map((u) => u.toJson()).toList(),
  };

  // --- copyWith Method ---
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
