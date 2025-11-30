import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// Import the file containing the model definitions
// Assuming the model file is in the root directory (../army_unit_data.dart)
import 'package:squire/data/model/Army_list/Army_unit_data.dart';

// Note: If you put the model code directly into a lib/models directory,
// adjust the import path above accordingly.

void main() {
  group('ArmyUnitData.fromJson Parsing and Wounds Calculation', () {
    // --- Mock Data ---

    // 1. Standard Combat Unit (Infantry/Cavalry): Wounds should be calculated (3 * 4 = 12)
    final infantryJson = {
      'id': 'stk01',
      'name': 'Stark Sworn Swords',
      'faction': 'Stark',
      'role': 'unit',
      'tray': 'infantry',
      'points': 6,
      'defense': 4,
      'morale': 7,
      'wounds': 3, // Wounds per rank
      'speed': 5,
      'attacks': [
        {
          'name': 'Longswords',
          'type': 'melee',
          'hit': 4,
          'dice': [4, 3, 2],
        },
      ],
      'abilities': [
        {
          'name': 'Order: Fury',
          'effects': ['Gains +1 attack die.'],
        },
      ],
    };

    // 2. NCU (Non-Combat Unit): Wounds should use raw value (1)
    final ncuJson = {
      'id': 'stk07',
      'name': 'Catelyn Stark',
      'faction': 'Stark',
      'role': 'ncu',
      'tray': 'ncu',
      'points': 4,
      'baseWounds': 1, // Raw total wounds
    };

    // 3. Solo/Monster Unit: Wounds should use raw value (e.g., 5)
    final soloJson = {
      'id': 'stk06',
      'name': 'Brynden Tully - Knight of the Gate',
      'faction': 'Stark',
      'role': 'attachment',
      'tray': 'solo',
      'points': 3,
      'wounds': 5, // Raw total wounds
    };

    // 4. Missing/Null Data: Test resilience and default values
    final sparseJson = {
      'id': 'unk01',
      'name': 'Sparse Unit',
      'faction': 'Neutral',
      'tray': 'infantry',
      // Missing 'wounds', 'defense', 'morale', 'attacks', 'abilities'
    };

    // 5. Combat Unit with Wounds missing, but tray is 'infantry': Should default to 12
    final missingWoundsJson = {
      'id': 'stk02',
      'name': 'Karstark Spearmen',
      'faction': 'Stark',
      'tray': 'infantry',
      'role': 'unit',
      'defense': 4,
      // 'wounds' is missing or null
    };

    // --- Tests ---

    test(
      '1. Should correctly parse a standard Combat Unit (Infantry) and calculate total wounds',
      () {
        final unit = ArmyUnitData.fromJson(infantryJson);

        expect(unit.id, 'stk01');
        expect(unit.name, 'Stark Sworn Swords');
        expect(unit.faction, 'Stark');
        expect(unit.role, 'unit');
        expect(unit.tray, 'infantry');
        expect(unit.defense, 4);
        expect(unit.morale, 7);

        // CRITICAL ASSERTION: 3 wounds-per-rank * 4 ranks = 12 total wounds
        expect(unit.baseWounds, 12);

        // Attacks and Abilities
        expect(unit.attacks.length, 1);
        expect(unit.attacks.first.name, 'Longswords');
        expect(unit.abilities.length, 1);
        expect(unit.abilities.first.name, 'Order: Fury');
      },
    );

    test(
      '2. Should correctly parse an NCU and use the raw baseWounds value',
      () {
        final unit = ArmyUnitData.fromJson(ncuJson);

        expect(unit.name, 'Catelyn Stark');
        expect(unit.role, 'ncu');
        expect(unit.tray, 'ncu');

        // CRITICAL ASSERTION: Should use the raw value of 1
        expect(unit.baseWounds, 1);

        // Defense, Morale, Speed should be null
        expect(unit.defense, isNull);
        expect(unit.morale, isNull);
        expect(unit.speed, isNull);
      },
    );

    test(
      '3. Should correctly parse a Solo and use the raw wounds value (no multiplication)',
      () {
        final unit = ArmyUnitData.fromJson(soloJson);

        expect(unit.name, 'Brynden Tully - Knight of the Gate');
        expect(unit.tray, 'solo');

        // CRITICAL ASSERTION: Should use the raw value of 5
        expect(unit.baseWounds, 5);
      },
    );

    test('4. Should handle sparse JSON data and apply safe defaults/nulls', () {
      final unit = ArmyUnitData.fromJson(sparseJson);

      expect(unit.name, 'Sparse Unit');
      expect(unit.faction, 'Neutral');

      // Verify nulls for missing properties
      expect(unit.defense, isNull);
      expect(unit.morale, isNull);
      expect(unit.points, isNull);
      expect(unit.baseWounds, 12); // Fallback for infantry tray

      // Verify empty lists for missing arrays
      expect(unit.attacks, isEmpty);
      expect(unit.abilities, isEmpty);
    });

    test(
      '5. Should fall back to 12 wounds if combat unit tray is present but wounds value is missing',
      () {
        final unit = ArmyUnitData.fromJson(missingWoundsJson);

        expect(unit.name, 'Karstark Spearmen');
        expect(unit.tray, 'infantry');

        // CRITICAL ASSERTION: Because 'wounds' was missing, the final resilience check
        // should force it to the combat unit default of 12.
        expect(unit.baseWounds, 12);
      },
    );

    test('6. Should handle Ability parsing when effect is a list', () {
      final jsonWithListEffect = {
        'id': 'stk01',
        'name': 'Test Unit',
        'faction': 'Stark',
        'attacks': [],
        'abilities': [
          {
            'name': 'Test Ability',
            'effects': ['Line 1 of effect.', 'Line 2 of effect.'],
          },
        ],
      };
      final unit = ArmyUnitData.fromJson(jsonWithListEffect);
      expect(unit.abilities.length, 1);
      expect(unit.abilities.first.name, 'Test Ability');
      expect(unit.abilities.first.effects.length, 2);
      expect(unit.abilities.first.effects.first, 'Line 1 of effect.');
    });

    test(
      '7. Should handle Ability parsing when effect is a singular string',
      () {
        final jsonWithSingleEffect = {
          'id': 'stk01',
          'name': 'Test Unit',
          'faction': 'Stark',
          'attacks': [],
          'abilities': [
            {'name': 'Single Effect', 'effect': 'This is the only line.'},
          ],
        };
        final unit = ArmyUnitData.fromJson(jsonWithSingleEffect);
        expect(unit.abilities.length, 1);
        expect(unit.abilities.first.name, 'Single Effect');
        expect(unit.abilities.first.effects.length, 1);
        expect(unit.abilities.first.effects.first, 'This is the only line.');
      },
    );
  });
}
