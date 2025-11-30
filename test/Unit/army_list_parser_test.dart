import 'package:flutter_test/flutter_test.dart';
// Note: We are using a relative import path here. Adjust if necessary.
import 'package:squire/data/services/army_list_parser.dart';

// --- MOCK MODEL DEFINITIONS (To prevent import errors) ---

// Assuming Army_unit_data.dart contains UnitEntry
class UnitEntry {
  final String unitName;
  final int unitCost;
  final String? attachmentName;
  final int? attachmentCost;
  final String type; // 'combat' or 'ncu'

  UnitEntry({
    required this.unitName,
    required this.unitCost,
    this.attachmentName,
    this.attachmentCost,
    required this.type,
  });

  factory UnitEntry.combatUnit({
    required String unitName,
    required int unitCost,
    String? attachmentName,
    int? attachmentCost,
  }) {
    return UnitEntry(
      unitName: unitName,
      unitCost: unitCost,
      attachmentName: attachmentName,
      attachmentCost: attachmentCost,
      type: 'combat',
    );
  }

  factory UnitEntry.ncu({required String unitName, required int unitCost}) {
    return UnitEntry(unitName: unitName, unitCost: unitCost, type: 'ncu');
  }

  UnitEntry copyWith({String? attachmentName, int? attachmentCost}) {
    return UnitEntry(
      unitName: unitName,
      unitCost: unitCost,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentCost: attachmentCost ?? this.attachmentCost,
      type: type,
    );
  }
}

// Assuming Army_unit_data.dart contains ListPa
class ListPa {
  final String faction;
  final String commanderName;
  final int totalPoints;
  final int totalActivations;
  final List<UnitEntry> combatUnits;
  final List<UnitEntry> ncus;

  ListPa({
    required this.faction,
    required this.commanderName,
    required this.totalPoints,
    required this.totalActivations,
    required this.combatUnits,
    required this.ncus,
  });
}
// --- END MOCK MODEL DEFINITIONS ---

void main() {
  // The original ArmyListParser needs to be imported relative to your project root.
  // I am assuming the provided file path is correct relative to the test directory:
  final parser = ArmyListParser();

  group('ArmyListParser Unit Tests', () {
    // Test Case 1: Full Valid List Parsing (Happy Path)
    test(
      'Should correctly parse a full list with Units, Attachments, and NCUs',
      () {
        const rawList = '''
Faction : STARK
Commander : Robb Stark - The Wolf Lord | Points: 40 / 40
Points : 40
Activations : 7

Units :
• Stark Sworn Swords (6)
  with Catelyn Stark (3)
• Crannogman Trackers (5)
• Umber Berserkers (7)

Non-Combat Unit :
• Sansa Stark (5)
• Petyr Baelish - Littlefinger (4)
''';

        final result = parser.parseArmyList(rawList);

        // Verify header data
        expect(result.faction, 'STARK');
        expect(result.commanderName, 'Robb Stark - The Wolf Lord');
        expect(result.totalPoints, 40);
        expect(result.totalActivations, 7);

        // Verify Combat Units
        expect(result.combatUnits.length, 3);

        // Unit 1 (with attachment)
        expect(result.combatUnits[0].unitName, 'Stark Sworn Swords');
        expect(result.combatUnits[0].unitCost, 6);
        expect(result.combatUnits[0].attachmentName, 'Catelyn Stark');
        expect(result.combatUnits[0].attachmentCost, 3);

        // Unit 2 (no attachment)
        expect(result.combatUnits[1].unitName, 'Crannogman Trackers');
        expect(result.combatUnits[1].unitCost, 5);
        expect(result.combatUnits[1].attachmentName, isNull);

        // Verify NCUs
        expect(result.ncus.length, 2);
        expect(result.ncus[0].unitName, 'Sansa Stark');
        expect(result.ncus[0].unitCost, 5);
        expect(result.ncus[1].unitName, 'Petyr Baelish - Littlefinger');
        expect(result.ncus[1].unitCost, 4);
      },
    );

    // Test Case 4: Handling missing cost parenthetical
    test(
      'Should default cost to 0 if cost parenthetical is missing or invalid',
      () {
        const rawList = '''
Faction : Baratheon
Units :
• Stag Knights
• R'hllor Faithful (X)
''';
        final result = parser.parseArmyList(rawList);
        expect(result.combatUnits.length, 2);
        expect(result.combatUnits[0].unitName, 'Stag Knights');
        expect(result.combatUnits[0].unitCost, 0); // Missing cost defaults to 0
        expect(result.combatUnits[1].unitName, "R'hllor Faithful");
        expect(result.combatUnits[1].unitCost, 0); // Invalid cost defaults to 0
      },
    );
  });
}
