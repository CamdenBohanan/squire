import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// --- Imports from your project structure ---
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/repositories/Ability_Repository.dart';
import 'package:squire/view_models/home_view_model.dart';

// CRITICAL FIX: Alias the data model import to resolve type conflicts (used throughout)
import 'package:squire/data/model/Army_list/Army_unit_data.dart' as list_models;
import 'package:squire/data/services/army_list_parser.dart';
import 'package:squire/data/services/unit_details_service.dart';
import 'package:squire/view/UnitDetailsScreen.dart'; // Using the user's specified path

// Import the mocks file
import 'army_list_acceptance_test.mocks.dart';

// --- Mock Setup ---
@GenerateMocks([UnitRepository, AbilityRepository, UnitDetailsService])
// --- Helper class to mock the target screen for the test harness ---
class MockArmyListLoadedScreen extends StatelessWidget {
  const MockArmyListLoadedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HomeViewModel>(context);

    // FIX: Access combat units via the public `listPa` property,
    // as `combatUnits` is not exposed directly on the ViewModel.
    final List<dynamic> rawUnits = viewModel.listPa?.combatUnits ?? [];

    return Scaffold(
      key: const Key('army_loaded_screen'),
      body: ListView(
        children: rawUnits.map((unit) {
          final list_models.UnitEntry unitEntry = unit as list_models.UnitEntry;
          return ListTile(
            key: Key('unit_card_${unitEntry.unitName}'),
            title: Text(unitEntry.unitName),
            onTap: () {
              // Simulate navigation to UnitDetailsScreen, which is the SUT
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UnitDetailsScreen(unit: unitEntry),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

// Helper Widget to handle the initial load and screen transition
class _TestHome extends StatefulWidget {
  final HomeViewModel viewModel;
  const _TestHome({required this.viewModel});

  @override
  State<_TestHome> createState() => _TestHomeState();
}

// --- Comprehensive Mock Raw List String (Defined globally for use in _TestHomeState) ---
const mockRawList = """
Faction : House Stark
Commander : Robb Stark - The Young Wolf (0) | Points: 40
Points : 40
Activations : 6

Units :
• Stark Sworn Swords (6)
 with Catelyn Stark - The Negotiator (3)
• Crannogmen Trackers (5)

Non-Combat Unit :
• Sansa Stark - Little Bird (4)
""";

class _TestHomeState extends State<_TestHome> {
  bool _isLoaded = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate text field for the test flow
    _controller.text = mockRawList;
  }

  Future<void> _loadArmyList() async {
    // NOTE TO USER: 'parseArmyList' is the correct method name in the ViewModel.
    await widget.viewModel.parseArmyList(_controller.text);
    if (mounted) {
      setState(() {
        _isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoaded) {
      // Navigates to the mocked loaded screen once data is processed
      return const MockArmyListLoadedScreen();
    }

    // Initial input screen state for the test
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                key: const Key('list_input_field'),
                controller: _controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Army List Input',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('load_button'),
              onPressed: _loadArmyList,
              child: const Text('Load Army'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  late MockUnitRepository mockUnitRepository;
  late MockAbilityRepository mockAbilityRepository;

  // Instance of the REAL parser to use in the mock repository
  final realParser = ArmyListParser();

  // --- Mock Unit Details Data (Using aliased types) ---
  final commanderDetails = list_models.ArmyUnitData(
    id: '10101',
    name: 'Robb Stark',
    title: 'The Young Wolf',
    faction: 'STARK',
    role: 'Commander',
    baseWounds: 1,
    attacks: [],
    abilities: [],
  );

  final starkSwordsDetails = list_models.ArmyUnitData(
    id: '30123',
    name: 'Stark Sworn Swords',
    faction: 'STARK',
    role: 'Combat Unit',
    // wounds-per-rank (3) which the model calculates to 12 total.
    baseWounds: 12,
    defense: 4,
    morale: 7,
    attacks: [
      list_models.AttackProfile(
        name: 'Melee',
        type: 'melee',
        hit: 3,
        dice: [6, 4, 2, 0],
      ),
    ],
    abilities: [
      list_models.Ability(
        name: 'Set for Charge',
        effects: ['Melee attack rule text.'],
      ),
    ],
    tray: 'infantry',
  );

  final catelynAttachmentDetails = list_models.ArmyUnitData(
    id: '10102',
    name: 'Catelyn Stark',
    title: 'The Negotiator',
    faction: 'STARK',
    role: 'Attachment',
    baseWounds: 1,
    attacks: [],
    abilities: [
      list_models.Ability(
        name: 'Inspiring Presence',
        effects: ['Attachment morale bonus.'],
      ),
    ],
  );

  final sansaNcuDetails = list_models.ArmyUnitData(
    id: '10103',
    name: 'Sansa Stark',
    title: 'Little Bird',
    faction: 'STARK',
    role: 'NCU',
    baseWounds: 1,
    attacks: [],
    abilities: [
      list_models.Ability(
        name: 'Little Bird',
        effects: ['Provides tactical information.'],
      ),
    ],
    tray: 'ncu',
  );

  // Sets up the environment for the test using the HomeViewModel
  Widget createTestApp() {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (context) => HomeViewModel(
        repository: mockUnitRepository, // Injected Mock
        abilityRepository: mockAbilityRepository, // Injected Mock
      ),
      // Use the now top-level helper widget _TestHome
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            final viewModel = Provider.of<HomeViewModel>(
              context,
              listen: false,
            );
            return _TestHome(viewModel: viewModel);
          },
        ),
      ),
    );
  }

  setUp(() {
    mockUnitRepository = MockUnitRepository();
    mockAbilityRepository = MockAbilityRepository();

    reset(mockUnitRepository);
    reset(mockAbilityRepository);

    // ARRANGE 1: Mock the AbilityRepository calls
    when(
      mockAbilityRepository.fetchAndCacheAllAbilityEffects(),
    ).thenAnswer((_) async {});
    when(mockAbilityRepository.getAbilityRule(any)).thenAnswer((
      Invocation inv,
    ) {
      final abilityName = inv.positionalArguments[0] as String;
      // Use the name wrapped in stars to match the ViewModel output format
      return '**$abilityName**:\n$abilityName rule text is available.';
    });

    // ARRANGE 2: MockUnitRepository behavior: use REAL parser then attach MOCK details
    when(mockUnitRepository.parseListAndFetchDetails(any)).thenAnswer((
      Invocation inv,
    ) async {
      final rawList = inv.positionalArguments[0] as String;

      // FIX: Use the 'realParser' instance instead of static call
      list_models.ListPa parsedList = realParser.parseArmyList(rawList);

      // Simulate fetching details by matching names to mock data
      List<list_models.UnitEntry>
      enrichedCombatUnits = parsedList.combatUnits.map((unit) {
        if (unit.unitName == starkSwordsDetails.name) {
          return unit.copyWith(
            unitDetails: starkSwordsDetails,
            attachmentDetails: unit.attachmentName != null
                ? catelynAttachmentDetails.copyWith(title: 'The Negotiator')
                : null,
          );
        }
        // Crannogmen Trackers get a generic detail placeholder so they show up
        if (unit.unitName == 'Crannogmen Trackers') {
          return unit.copyWith(
            unitDetails: starkSwordsDetails.copyWith(
              id: '30124',
              name: 'Crannogmen Trackers',
              baseWounds: 8, // Total Wounds: 8
              defense: 5,
              morale: 8,
              tray: 'infantry',
              attacks: [
                list_models.AttackProfile(
                  name: 'Ranged',
                  type: 'long',
                  hit: 4,
                  dice: [
                    4,
                    2,
                    0,
                  ], // Full dice: 4, Mid: 2, Low: 0 (3 ranks for 8 wounds)
                ),
              ],
            ),
          );
        }
        return unit;
      }).toList();

      List<list_models.UnitEntry> enrichedNCUs = parsedList.ncus.map((unit) {
        // Must match the full name "Sansa Stark - Little Bird" for the parser output
        if (unit.unitName.contains('Sansa Stark')) {
          return unit.copyWith(
            unitDetails: sansaNcuDetails.copyWith(title: 'Little Bird'),
          );
        }
        return unit;
      }).toList();

      return parsedList.copyWith(
        commanderDetails: commanderDetails.copyWith(title: 'The Young Wolf'),
        combatUnits: enrichedCombatUnits,
        ncus: enrichedNCUs,
      );
    });
  });

  group('Army List Acceptance Test (Full Flow & State Check)', () {
    testWidgets(
      'Should transition from input to loaded screen and verify state changes (Activation/Wounds/Modifiers)',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        // --- PHASE 1: Load and Transition ---

        // The _TestHome widget automatically populated the text field.
        // We just need to tap the load button.
        await tester.tap(find.byKey(const Key('load_button')));
        await tester
            .pumpAndSettle(); // Loads data and transitions to MockArmyListLoadedScreen

        expect(find.byKey(const Key('army_loaded_screen')), findsOneWidget);

        // Find the Stark Sworn Swords unit card on the MockArmyListLoadedScreen
        const combatUnitName = 'Stark Sworn Swords';
        final starkSwordsCard = find.byKey(Key('unit_card_$combatUnitName'));

        // Ensure the card exists before tapping
        expect(starkSwordsCard, findsOneWidget);

        // --- PHASE 2: Check UnitDetailsScreen elements (Stark Sworn Swords) ---

        // 1. WHEN: User taps the unit card to navigate to details screen
        await tester.tap(starkSwordsCard);
        await tester.pumpAndSettle(); // Navigate to UnitDetailsScreen

        expect(
          find.text(combatUnitName),
          findsAtLeast(2),
        ); // Title and Card header
        expect(
          find.text('Attached: Catelyn Stark - The Negotiator'),
          findsOneWidget,
        );

        // 2. VERIFY: Initial Modifiers are displayed as +0
        // Attack, Defense, Defense Dice, Morale
        expect(find.text('+0'), findsAtLeast(4));

        // 3. VERIFY: Initial Wounds/Rank (12 max wounds for Sworn Swords: 3 wounds/rank * 4 ranks)
        expect(find.text('12 / 12'), findsOneWidget); // Wounds Remaining
        expect(find.text('Current Rank: 3 (Full Dice)'), findsOneWidget);
        expect(
          find.text('Melee Roll (6D6 | Hit 3+)'),
          findsOneWidget,
        ); // Initial attack dice

        // --- PHASE 3: Modifier Interaction Test ---

        // 4. Attack Modifier Test (Increase)
        final attackModifierLabel = find.text(
          'Attack Roll Modifier (Target Roll: 3+)',
        );
        // FIX: Using find.ancestor/find.descendant to resolve the .parent error
        final attackModifierContainer = find.ancestor(
          of: attackModifierLabel,
          matching: find.byType(Row), // Assuming the controls are in a Row
        );
        final attackModifierPlusButton = find.descendant(
          of: attackModifierContainer,
          matching: find.byIcon(Icons.add_circle_outline),
        );

        await tester.tap(attackModifierPlusButton);
        await tester.pump();

        // Verify UI update: Attack Modifier should be +1
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == '+1',
          ),
          findsAtLeast(1),
        );
        // Check if the Target Roll display updates (3+ becomes 2+)
        expect(
          find.text('Attack Roll Modifier (Target Roll: 2+)'),
          findsOneWidget,
        );

        // 5. Morale Modifier Test (Decrease and Reset)
        final moraleModifierLabel = find.textContaining(
          'Morale Check Modifier',
        );
        // FIX: Using find.ancestor/find.descendant to resolve the .parent error
        final moraleModifierContainer = find.ancestor(
          of: moraleModifierLabel,
          matching: find.byType(Row),
        );

        final moraleModifierMinusButton = find.descendant(
          of: moraleModifierContainer,
          matching: find.byIcon(Icons.remove_circle_outline),
        );
        final moraleModifierResetButton = find.descendant(
          of: moraleModifierContainer,
          matching: find.byIcon(Icons.clear),
        );

        await tester.tap(moraleModifierMinusButton);
        await tester.tap(moraleModifierMinusButton); // Decrease to -2
        await tester.pump();

        // Verify UI update: Morale Modifier should be -2
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == '-2',
          ),
          findsOneWidget,
        );

        await tester.tap(moraleModifierResetButton);
        await tester.pump();

        // Verify UI update: Morale Modifier should be +0 (Reset)
        final moraleRow = find.ancestor(
          of: find.textContaining('Morale Check Modifier'),
          matching: find.byType(Column),
        );
        expect(
          find.descendant(of: moraleRow, matching: find.text('+0')),
          findsOneWidget,
        );

        // --- PHASE 4: Wound Rank Display Test (Crannogmen Trackers - 8 Max Wounds) ---

        // Go back to the list screen
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        const trackerUnitName = 'Crannogmen Trackers';
        final trackerCard = find.byKey(Key('unit_card_$trackerUnitName'));

        // Navigate to Tracker Details Screen
        await tester.tap(trackerCard);
        await tester.pumpAndSettle();

        // Initial state for Trackers (8 Max Wounds: 2 wounds/rank * 4 ranks):
        expect(find.text('8 / 8'), findsOneWidget);
        expect(
          find.text('Current Rank: 3 (Full Dice)'),
          findsOneWidget,
        ); // 8 remaining > 8*2/3=5.33
        expect(
          find.text('Ranged Roll (4D6 | Hit 4+)'),
          findsOneWidget,
        ); // Attack dice (2 dice/rank * 2 ranks)

        // Find the wounds plus button (for damage taken)
        final woundsRemainingLabel = find.text('Wounds Remaining');
        // FIX: Using find.ancestor/find.descendant to resolve the .parent error
        final woundsControlRow = find.ancestor(
          of: woundsRemainingLabel,
          matching: find.byType(Row),
        );
        final woundsPlusButton = find.descendant(
          of: woundsControlRow,
          matching: find.byIcon(Icons.exposure_plus_1),
        );

        // Tap 3 times to take 3 wounds (5 remaining)
        // Rank 2: 5 remaining > 8*1/3=2.66 and <= 8*2/3=5.33
        await tester.tap(woundsPlusButton);
        await tester.tap(woundsPlusButton);
        await tester.tap(woundsPlusButton);
        await tester.pump();

        expect(find.text('5 / 8'), findsOneWidget);
        expect(find.text('Current Rank: 2 (Mid Dice)'), findsOneWidget);
        // Verify Attack Dice dropped: (2 dice/rank * 2 ranks) = 4 dice total
        expect(find.text('Ranged Roll (4D6 | Hit 4+)'), findsOneWidget);

        // Simulate taking damage: 6 wounds taken (2 remaining)
        // Rank 1: 2 remaining > 0 and <= 8*1/3=2.66
        await tester.tap(woundsPlusButton);
        await tester.tap(woundsPlusButton);
        await tester.tap(woundsPlusButton); // 6 wounds taken (2 remaining)
        await tester.pump();

        expect(find.text('2 / 8'), findsOneWidget);
        expect(find.text('Current Rank: 1 (Low Dice)'), findsOneWidget);
        // Verify Attack Dice dropped: (2 dice/rank * 1 rank) = 2 dice total
        expect(find.text('Ranged Roll (2D6 | Hit 4+)'), findsOneWidget);

        // Simulate destruction: 8 wounds taken (0 remaining)
        await tester.tap(woundsPlusButton);
        await tester.tap(woundsPlusButton); // 8 wounds taken (0 remaining)
        await tester.pump();

        expect(find.text('0 / 8'), findsOneWidget);
        expect(find.text('Unit Routed/Destroyed!'), findsOneWidget);
        expect(find.text('Unit Destroyed/Broken!'), findsOneWidget);
        // Verify Attack Dice is 0, preventing the roll button from working
        expect(find.text('Ranged Roll (0D6 | Hit 4+)'), findsOneWidget);

        // --- End Acceptance Test ---
      },
    );
  });
}
