import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Import the source files (you'll need to adjust these paths)
// Assuming HomeViewModel is in lib/view_models/home_view_model.dart
import 'package:squire/view_models/home_view_model.dart';
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/repositories/Ability_Repository.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart'; // Models defined here

// --- MOCK GENERATION SETUP ---
// We need to generate mocks for the repository dependencies.
@GenerateMocks([UnitRepository, AbilityRepository])
import 'home_view_model_test.mocks.dart';

// --- MINIMAL MOCK DATA SETUP ---

// Recreating minimal AttackProfile structure for testing unit logic
AttackProfile createAttackProfile({
  required List<int> dice,
  String type = 'melee',
  int hit = 4,
}) {
  return AttackProfile(name: 'Test Attack', type: type, hit: hit, dice: dice);
}

// Recreating minimal ArmyUnitData structure for testing unit logic
ArmyUnitData createUnitData({
  required String name,
  required int baseWounds,
  List<AttackProfile>? attacks,
  List<Ability>? abilities,
  int defense = 4,
  int morale = 7,
}) {
  return ArmyUnitData(
    id: name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    faction: 'Stark',
    baseWounds: baseWounds,
    defense: defense,
    morale: morale,
    attacks: attacks ?? [],
    abilities: abilities ?? [],
  );
}

// Recreating UnitEntry for state tracking
UnitEntry createUnitEntry({
  required String name,
  ArmyUnitData? details,
  String? attachmentName,
  ArmyUnitData? attachmentDetails,
}) {
  return UnitEntry(
    unitName: name,
    attachmentName: attachmentName,
    unitDetails: details,
    attachmentDetails: attachmentDetails,
    currentWounds: 0,
    isActivated: false,
    attackModifier: 0,
    defenseModifier: 0,
    moraleModifier: 0,
    defenseDiceModifier: 0,
  );
}

// Recreating ListPa for the main state object
ListPa createListPa({
  List<UnitEntry>? combatUnits,
  List<UnitEntry>? ncus,
  ArmyUnitData? commanderDetails,
}) {
  return ListPa(
    faction: 'Stark',
    commanderName: 'Robb Stark',
    commanderDetails: commanderDetails,
    combatUnits: combatUnits ?? [],
    ncus: ncus ?? [],
  );
}
// --- END MOCK DATA SETUP ---

void main() {
  // Use the generated mock classes
  late MockUnitRepository mockUnitRepository;
  late MockAbilityRepository mockAbilityRepository;
  late HomeViewModel viewModel;

  // --- MOCK UNIT DATA ---
  // 12-Wound Infantry Unit (3 Ranks: 4 dice, 3 dice, 2 dice)
  final swornSwordsData = createUnitData(
    name: 'Stark Sworn Swords',
    baseWounds: 12,
    defense: 4,
    morale: 7,
    attacks: [
      createAttackProfile(dice: [4, 3, 2], type: 'melee', hit: 4),
    ],
    abilities: [
      Ability(name: 'Order: Set for Charge', effects: ['effect']),
      Ability(name: 'Critical Blow', effects: ['effect']),
    ],
  );
  final swornSwordsEntry = createUnitEntry(
    name: 'Stark Sworn Swords',
    details: swornSwordsData,
  );

  // 4-Wound Monster/Solo Unit (1 Rank: 5 dice)
  final monsterData = createUnitData(
    name: 'Giant',
    baseWounds: 4,
    defense: 3,
    morale: 6,
    attacks: [
      createAttackProfile(dice: [5], type: 'melee', hit: 3),
    ],
  );
  final monsterEntry = createUnitEntry(name: 'Giant', details: monsterData);

  // 1-Wound NCU
  final catelynData = createUnitData(name: 'Catelyn Stark', baseWounds: 1);
  final catelynEntry = createUnitEntry(
    name: 'Catelyn Stark',
    details: catelynData,
  );

  // ListPa representing the initial parsed list
  final initialListPa = createListPa(
    combatUnits: [swornSwordsEntry, monsterEntry],
    ncus: [catelynEntry],
  );

  setUp(() {
    mockUnitRepository = MockUnitRepository();
    mockAbilityRepository = MockAbilityRepository();
    viewModel = HomeViewModel(
      repository: mockUnitRepository,
      abilityRepository: mockAbilityRepository,
    );
    // Mock the ability repository to return *something* for enrichment testing
    when(
      mockAbilityRepository.getAbilityRule(any),
    ).thenReturn('Rule text found.\nMulti-line effect.');
    when(
      mockAbilityRepository.fetchAndCacheAllAbilityEffects(),
    ).thenAnswer((_) async {});
  });

  group('A. Core Loading and State Initialization', () {
    test(
      'parseArmyList sets loading state and initializes listPa on success',
      () async {
        // Arrange
        const rawText = 'My Army List';
        when(
          mockUnitRepository.parseListAndFetchDetails(rawText),
        ).thenAnswer((_) async => initialListPa);

        // Act
        final future = viewModel.parseArmyList(rawText);

        // Assert: Check loading state during async call
        expect(viewModel.isLoading, isTrue);

        await future;

        // Assert: Check final state
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isEmpty);
        expect(viewModel.listPa, isNotNull);

        // Check initialization: Wounds should be 0, activated should be false
        expect(viewModel.listPa!.combatUnits.first.currentWounds, 0);
        expect(viewModel.listPa!.combatUnits.first.isActivated, isFalse);
      },
    );

    test('parseArmyList handles repository error gracefully', () async {
      // Arrange
      const rawText = 'Bad List';
      when(
        mockUnitRepository.parseListAndFetchDetails(rawText),
      ).thenThrow(Exception('Parsing failed'));

      // Act
      await viewModel.parseArmyList(rawText);

      // Assert
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, contains('Parsing failed'));
      expect(viewModel.listPa, isNull);
    });
  });

  group('B. Tactical State Modifiers and Getters', () {
    // Load the initial state before running modifier tests
    setUp(() {
      viewModel.loadArmyList(initialListPa);
    });

    test('updateDefenseModifier should clamp values between -5 and 5', () {
      // Act: Set high value
      viewModel.updateDefenseModifier(swornSwordsEntry.unitName, modifier: 10);
      // Assert: Should clamp to 5
      expect(viewModel.listPa!.combatUnits.first.defenseModifier, 5);

      // Act: Set low value
      viewModel.updateDefenseModifier(swornSwordsEntry.unitName, modifier: -10);
      // Assert: Should clamp to -5
      expect(viewModel.listPa!.combatUnits.first.defenseModifier, -5);
    });

    test(
      'getDefenseSaveTarget should adjust based on modifier and clamp target',
      () {
        // Base Save for Sworn Swords is 4 (4+)

        // Act 1: No modifier
        expect(viewModel.getDefenseSaveTarget(swornSwordsEntry), 4);

        // Act 2: +1 modifier (makes a 5+ save)
        viewModel.updateDefenseModifier(swornSwordsEntry.unitName, modifier: 1);
        final updatedUnit = viewModel.getUnitState(swornSwordsEntry);
        expect(viewModel.getDefenseSaveTarget(updatedUnit), 5); // 4 + 1 = 5

        // Act 3: Extreme modifier (makes a 7+ save)
        viewModel.updateDefenseModifier(swornSwordsEntry.unitName, modifier: 3);
        final maxClampedUnit = viewModel.getUnitState(swornSwordsEntry);
        expect(
          viewModel.getDefenseSaveTarget(maxClampedUnit),
          6,
        ); // (4 + 3) = 7, Clamped to 6
      },
    );

    test('getToHitTarget should adjust based on modifier and clamp target', () {
      // Base To-Hit for Sworn Swords is 4 (4+)

      // Act 1: No modifier
      expect(viewModel.getToHitTarget(swornSwordsEntry, 'melee'), 4);

      // Act 2: +1 modifier (makes a 5+ hit)
      viewModel.updateAttackModifier(swornSwordsEntry.unitName, modifier: 1);
      final updatedUnit = viewModel.getUnitState(swornSwordsEntry);
      expect(viewModel.getToHitTarget(updatedUnit, 'melee'), 5); // 4 + 1 = 5

      // Act 3: Negative modifier (makes a 3+ hit)
      viewModel.updateAttackModifier(swornSwordsEntry.unitName, modifier: -1);
      final minClampedUnit = viewModel.getUnitState(swornSwordsEntry);
      expect(viewModel.getToHitTarget(minClampedUnit, 'melee'), 3); // 4 - 1 = 3
    });
  });

  group('C. Wounds and Rank Degradation Logic (getAttackDiceForUnit)', () {
    setUp(() {
      viewModel.loadArmyList(initialListPa);
    });

    test('12-Wound Unit: Full Rank (0-3 Wounds Lost)', () {
      // 0 wounds lost: Rank 3 (index 0)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 0);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        4,
      );

      // 3 wounds lost: Still Rank 3 (index 0)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 3);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        4,
      );
    });

    test('12-Wound Unit: Middle Rank (4-7 Wounds Lost)', () {
      // 4 wounds lost: Rank 2 (index 1)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 4);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        3,
      );

      // 7 wounds lost: Still Rank 2 (index 1)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 7);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        3,
      );
    });

    test('12-Wound Unit: Final Rank (8-11 Wounds Lost)', () {
      // 8 wounds lost: Rank 1 (index 2)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 8);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        2,
      );

      // 11 wounds lost: Still Rank 1 (index 2)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 11);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        2,
      );
    });

    test('12-Wound Unit: Destroyed (12+ Wounds Lost)', () {
      // 12 wounds lost: Destroyed (0 dice)
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 12);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        0,
      );

      // Wounds are clamped, but check logic
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 15);
      expect(
        viewModel.getAttackDiceForUnit(
          viewModel.getUnitState(swornSwordsEntry),
          'melee',
        ),
        0,
      );
    });

    test(
      'Multi-Wound Unit (Giant): Half-wounds degradation (4 max, 1 rank drop at > 2 lost)',
      () {
        // The attack profile only has one rank ([5]), so it should always return 5 dice until destroyed.
        viewModel.updateWounds(monsterEntry.unitName, newWounds: 0);
        expect(
          viewModel.getAttackDiceForUnit(
            viewModel.getUnitState(monsterEntry),
            'melee',
          ),
          5,
        );

        // If we create a two-rank monster (e.g., [5, 3] dice)
        final twoRankMonsterData = createUnitData(
          name: 'Big Monster',
          baseWounds: 4,
          attacks: [
            createAttackProfile(dice: [5, 3], type: 'melee', hit: 3),
          ],
        );
        final twoRankMonsterEntry = createUnitEntry(
          name: 'Big Monster',
          details: twoRankMonsterData,
        );
        viewModel.loadArmyList(
          createListPa(combatUnits: [twoRankMonsterEntry]),
        );

        // 0-2 wounds lost: Rank 1 (5 dice)
        viewModel.updateWounds(twoRankMonsterEntry.unitName, newWounds: 2);
        expect(
          viewModel.getAttackDiceForUnit(
            viewModel.getUnitState(twoRankMonsterEntry),
            'melee',
          ),
          5,
        );

        // 3+ wounds lost (over half wounds): Rank 2 (3 dice)
        viewModel.updateWounds(twoRankMonsterEntry.unitName, newWounds: 3);
        expect(
          viewModel.getAttackDiceForUnit(
            viewModel.getUnitState(twoRankMonsterEntry),
            'melee',
          ),
          3,
        );

        // 4 wounds lost: Destroyed (0 dice)
        viewModel.updateWounds(twoRankMonsterEntry.unitName, newWounds: 4);
        expect(
          viewModel.getAttackDiceForUnit(
            viewModel.getUnitState(twoRankMonsterEntry),
            'melee',
          ),
          0,
        );
      },
    );
  });

  group('D. Ability Tracking and Keywords', () {
    setUp(() {
      viewModel.loadArmyList(initialListPa);
    });

    test('toggleAbilityUsed and isAbilityUsed work correctly', () {
      const abilityName = 'Order: Set for Charge';

      // Initial state
      expect(viewModel.isAbilityUsed(swornSwordsEntry, abilityName), isFalse);

      // Toggle ON
      viewModel.toggleAbilityUsed(swornSwordsEntry, abilityName);
      expect(
        viewModel.isAbilityUsed(
          viewModel.getUnitState(swornSwordsEntry),
          abilityName,
        ),
        isTrue,
      );

      // Toggle OFF
      viewModel.toggleAbilityUsed(swornSwordsEntry, abilityName);
      expect(
        viewModel.isAbilityUsed(
          viewModel.getUnitState(swornSwordsEntry),
          abilityName,
        ),
        isFalse,
      );
    });

    test('hasKeyword returns true for matching keyword (case-insensitive)', () {
      // Sworn Swords have 'Critical Blow'
      expect(viewModel.hasKeyword(swornSwordsEntry, 'Critical Blow'), isTrue);
      expect(viewModel.hasKeyword(swornSwordsEntry, 'critical blow'), isTrue);
      expect(viewModel.hasKeyword(swornSwordsEntry, 'Pillage'), isFalse);
    });

    test(
      'getUnitAbilities returns correctly formatted and enriched text',
      () async {
        // Act
        await viewModel.parseArmyList(
          'Test',
        ); // Re-run parse to trigger enrichment

        final abilities = viewModel.getUnitAbilities(
          viewModel.listPa!.combatUnits.first,
        );

        // Assert
        expect(abilities.length, 2);
        expect(abilities[0], startsWith('**Order: Set for Charge**'));
        expect(abilities[0], contains('Rule text found.\nMulti-line effect.'));
      },
    );
  });

  group('E. Reset and Activation', () {
    setUp(() {
      viewModel.loadArmyList(initialListPa);
    });

    test('toggleActivation toggles unit state', () {
      // Initial state
      expect(viewModel.listPa!.combatUnits.first.isActivated, isFalse);

      // Toggle ON
      viewModel.toggleActivation(swornSwordsEntry.unitName);
      expect(viewModel.listPa!.combatUnits.first.isActivated, isTrue);

      // Toggle OFF
      viewModel.toggleActivation(swornSwordsEntry.unitName);
      expect(viewModel.listPa!.combatUnits.first.isActivated, isFalse);
    });

    test('resetAllActivations resets all tactical state and ability usage', () {
      // 1. Arrange: Set a complex state
      viewModel.updateWounds(swornSwordsEntry.unitName, newWounds: 5);
      viewModel.toggleActivation(swornSwordsEntry.unitName);
      viewModel.updateDefenseModifier(swornSwordsEntry.unitName, modifier: 1);
      viewModel.toggleAbilityUsed(swornSwordsEntry, 'Order: Set for Charge');

      // Assert complex state is set
      expect(viewModel.listPa!.combatUnits.first.currentWounds, 5);
      expect(viewModel.listPa!.combatUnits.first.isActivated, isTrue);
      expect(viewModel.listPa!.combatUnits.first.defenseModifier, 1);
      expect(
        viewModel.isAbilityUsed(swornSwordsEntry, 'Order: Set for Charge'),
        isTrue,
      );

      // 2. Act
      viewModel.resetAllActivations();

      // 3. Assert: All state is reset
      expect(viewModel.listPa!.combatUnits.first.currentWounds, 0);
      expect(viewModel.listPa!.combatUnits.first.isActivated, isFalse);
      expect(viewModel.listPa!.combatUnits.first.defenseModifier, 0);
      expect(
        viewModel.isAbilityUsed(swornSwordsEntry, 'Order: Set for Charge'),
        isFalse,
      ); // Ability usage cleared
    });
  });
}
