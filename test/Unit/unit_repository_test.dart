import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Note: We are using a relative import path here. Adjust if necessary.
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/services/unit_details_service.dart'; // To mock the dependency
import 'package:squire/data/services/army_list_parser.dart'; // To mock the dependency

// CRITICAL FIX: Import the real models from the application's lib directory.
// 1. This import covers ListPa and ArmyUnitData based on your error message.
import 'package:squire/data/model/Army_list/Army_unit_data.dart';
// 2. We assume UnitEntry is also available through the existing imports or is globally accessible.

// --- 1. Setup Mockito and Mocks ---

// We need to mock the two dependencies of UnitRepository
@GenerateMocks([UnitDetailsService, ArmyListParser])
// Ensure this import path is correct after running the Mockito builder
import 'unit_repository_test.mocks.dart';

// --- Test Data Declarations (Private and Nullable at file level) ---
ArmyUnitData? _robbDetail;
ArmyUnitData? _swordsDetail;
ArmyUnitData? _catelynDetail;
ArmyUnitData? _berserkersDetail;
ArmyUnitData? _sansaDetail;

ListPa? _mockParsedList;
List<ArmyUnitData>? _mockFetchedDetails;
List<String>? _expectedNamesToFetch;
// --- End Test Data Declarations ---

void main() {
  late MockUnitDetailsService mockDetailsService;
  late MockArmyListParser mockParserService;
  late UnitRepository repository;

  // Define the common faction required by the models
  const testFaction = 'STARK';

  setUp(() {
    // 4. Initialize the mocks
    mockDetailsService = MockUnitDetailsService();
    mockParserService = MockArmyListParser();

    // --- Initialize Test Data within setUp() ---
    // CRITICAL FIX: Added the required 'faction' parameter to ArmyUnitData constructors.
    _robbDetail = ArmyUnitData(
      id: 'R1',
      name: 'Robb Stark',
      title: 'The Wolf Lord',
      faction: testFaction, // Required argument added
    );
    _swordsDetail = ArmyUnitData(
      id: 'U1',
      name: 'Stark Sworn Swords',
      faction: testFaction, // Required argument added
    );
    _catelynDetail = ArmyUnitData(
      id: 'A1',
      name: 'Catelyn Stark',
      faction: testFaction, // Required argument added
    );
    _berserkersDetail = ArmyUnitData(
      id: 'U2',
      name: 'Umber Berserkers',
      faction: testFaction, // Required argument added
    );
    _sansaDetail = ArmyUnitData(
      id: 'N1',
      name: 'Sansa Stark',
      faction: testFaction, // Required argument added
    );

    _mockParsedList = ListPa(
      faction: testFaction,
      commanderName: 'Robb Stark - The Wolf Lord',
      combatUnits: [
        UnitEntry(
          unitName: 'Stark Sworn Swords',
          attachmentName: 'Catelyn Stark',
        ),
        UnitEntry(unitName: 'Umber Berserkers'),
      ],
      ncus: [UnitEntry(unitName: 'Sansa Stark')],
    );

    _mockFetchedDetails = [
      _robbDetail!,
      _swordsDetail!,
      _catelynDetail!,
      _berserkersDetail!,
      _sansaDetail!,
    ];

    _expectedNamesToFetch = [
      'Robb Stark - The Wolf Lord',
      'Stark Sworn Swords',
      'Catelyn Stark',
      'Umber Berserkers',
      'Sansa Stark',
    ];
    // --- End Test Data Initialization ---

    // 5. Inject the mocks into the repository
    repository = UnitRepository(mockDetailsService, mockParserService);

    // Reset all mock settings before each test
    reset(mockDetailsService);
    reset(mockParserService);
  });

  group('UnitRepository Tests', () {
    test(
      'should successfully parse, fetch all details, and map them correctly',
      () async {
        // Use the non-null assertion operator '!' to access the variables
        final robbDetail = _robbDetail!;
        final swordsDetail = _swordsDetail!;
        final catelynDetail = _catelynDetail!;
        final sansaDetail = _sansaDetail!;
        final mockParsedList = _mockParsedList!;
        final mockFetchedDetails = _mockFetchedDetails!;
        final expectedNamesToFetch = _expectedNamesToFetch!;

        // 1. Arrange: Mock the parser output
        when(mockParserService.parseArmyList(any)).thenReturn(mockParsedList);

        // 2. Arrange: Mock the detail service output
        when(
          mockDetailsService.fetchUnitDetails(
            testFaction, // Expected faction
            expectedNamesToFetch, // Expected list of unique names
          ),
        ).thenAnswer((_) async => mockFetchedDetails);

        // 3. Act
        final resultList = await repository.parseListAndFetchDetails(
          'Test List Text',
        );

        // 4. Assert: Verify service calls
        verify(mockParserService.parseArmyList('Test List Text')).called(1);
        verify(
          mockDetailsService.fetchUnitDetails(
            testFaction,
            expectedNamesToFetch,
          ),
        ).called(1);

        // 5. Assert: Verify mapping
        expect(resultList.commanderDetails, equals(robbDetail));
        expect(resultList.combatUnits.length, 2);
        expect(resultList.ncus.length, 1);

        // Combat Unit 1 (Swords with Catelyn)
        final unit1 = resultList.combatUnits.firstWhere(
          (u) => u.unitName == 'Stark Sworn Swords',
        );
        expect(unit1.unitDetails, equals(swordsDetail));
        expect(unit1.attachmentDetails, equals(catelynDetail));

        // NCU (Sansa)
        final ncu1 = resultList.ncus.firstWhere(
          (u) => u.unitName == 'Sansa Stark',
        );
        expect(ncu1.unitDetails, equals(sansaDetail));
      },
    );

    test(
      'should return parsed list with null details if API fetch fails',
      () async {
        final mockParsedList = _mockParsedList!;

        // 1. Arrange: Mock parser output
        when(mockParserService.parseArmyList(any)).thenReturn(mockParsedList);

        // 2. Arrange: Mock detail service to throw an exception
        when(
          mockDetailsService.fetchUnitDetails(any, any),
        ).thenThrow(Exception('Network Failed'));

        // 3. Act
        final resultList = await repository.parseListAndFetchDetails(
          'Test List Text',
        );

        // 4. Assert: Verify fetch was attempted
        verify(mockDetailsService.fetchUnitDetails(any, any)).called(1);

        // 5. Assert: Verify mapping results in null details (graceful degradation)
        expect(resultList.commanderDetails, isNull);
        expect(resultList.combatUnits.first.unitDetails, isNull);
        expect(resultList.ncus.first.unitDetails, isNull);
      },
    );
  });
}
