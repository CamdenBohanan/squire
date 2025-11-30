import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Note: We are using a relative import path here. Adjust if necessary.
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/services/unit_details_service.dart';
import 'package:squire/data/services/army_list_parser.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart';

// CRITICAL FIX: All directives (imports) MUST be at the very top, before any class definitions.
// The generated file import must be here.
import 'repository_integration_test.mocks.dart';

// --- 1. Setup Mocks Annotation ---
// This annotation must appear after all imports and before the main function.
@GenerateMocks([UnitDetailsService, ArmyListParser, CacheRepository])
// --- 2. Declarations Start Here ---
// Hypothetical Cache Component (Mocked) - Must be defined before main()
class CacheRepository {
  Future<List<String>?> getCachedList(String listId) async => null;
  Future<void> cacheList(String listId, List<String> data) async => {};
}

void main() {
  late MockUnitDetailsService mockDetailsService;
  late MockArmyListParser mockParserService;
  late MockCacheRepository mockCacheRepository; // Mock created by build_runner
  late UnitRepository repository;

  setUp(() {
    mockDetailsService = MockUnitDetailsService();
    mockParserService = MockArmyListParser();
    mockCacheRepository = MockCacheRepository();

    // Injecting the two core dependencies for the UnitRepository integration test
    repository = UnitRepository(mockDetailsService, mockParserService);

    reset(mockDetailsService);
    reset(mockParserService);
    reset(mockCacheRepository);
  });

  group('Repository Dependency Integration Checks', () {
    const listText = 'Test List Text';

    // Mock data based on your previous test setup.
    final mockParsedList = ListPa(
      faction: 'STARK',
      commanderName: 'Robb',
      combatUnits: [],
      ncus: [],
    );
    final mockFetchedDetails = <ArmyUnitData>[];

    test('should call parser and detail service (original flow test)', () async {
      // ARRANGE
      when(
        mockParserService.parseArmyList(listText),
      ).thenReturn(mockParsedList);
      when(
        mockDetailsService.fetchUnitDetails(any, any),
      ).thenAnswer((_) async => mockFetchedDetails);

      // ACT
      await repository.parseListAndFetchDetails(listText);

      // ASSERT
      // Verify that the parser ran (Integration 1: Parser -> Repo)
      verify(mockParserService.parseArmyList(listText)).called(1);

      // Verify that the detail service ran (Integration 2: Repo -> DetailService)
      verify(mockDetailsService.fetchUnitDetails(any, any)).called(1);
    });

    // Test for integration failure handling
    test('should return an error state if parser fails', () async {
      // ARRANGE: Mock parser to throw an error
      when(
        mockParserService.parseArmyList(listText),
      ).thenThrow(Exception('Parser Error'));

      // ACT
      // We ensure the repository handles the exception gracefully
      await repository.parseListAndFetchDetails(listText);

      // ASSERT
      // Verify that the detail service was NEVER called because the parser failed
      verifyNever(mockDetailsService.fetchUnitDetails(any, any));
    });
  });
}
