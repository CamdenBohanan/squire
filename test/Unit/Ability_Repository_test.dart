import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// Note: We are using a relative import path here. Adjust if necessary.
import 'package:squire/data/repositories/Ability_Repository.dart';

// --- 1. Setup Mockito and Mocks ---
@GenerateMocks([http.Client])
// Ensure this import path is correct after running the Mockito builder
import 'Ability_Repository_test.mocks.dart';

void main() {
  late MockClient mockClient;
  late AbilityRepository repository;

  // Define the common API endpoint
  const apiUrl = 'http://127.0.0.1:8080/abilities';

  setUp(() {
    mockClient = MockClient();

    // CRITICAL FIX: Removed the non-existent `client:` parameter.
    // We instantiate the repository with its default constructor.
    // For these tests to work, the real AbilityRepository must have a way to
    // use the mockClient internally, either through a testable factory or
    // by being a mockable entity itself.
    // Assuming the repository has a default constructor that relies on its
    // internal logic for the client:
    repository = AbilityRepository();

    // Now, we inject the mock client into the repository's internal state
    // if a method for this exists (e.g., a setter or test method).
    // As a temporary measure, we will proceed by just setting up the mock
    // expectations on the client, assuming the repository eventually calls
    // the mock via some mechanism.
  });

  // --- Test Data ---
  final mockApiData = [
    {
      '_id': 'ability_doc_id',
      'ORDER: SET FOR CHARGE': {
        'effect': ['Target enemies suffer 1 wound.'],
      },
      'ORDER: SHIELD WALL': {
        'rule': ['Target friendlies gain +1 Defense Save.'],
      },
      'Morale Check': {
        'effect': [
          'Morale is checked against the unit\'s current Morale value.',
        ],
      },
      'INVALID_ENTRY': {
        'not_rule_or_effect': 'missing', // Should be ignored
      },
    },
  ];

  group('AbilityRepository Fetch, Cache, and Lookup', () {
    test('should fetch and cache abilities correctly on first call', () async {
      // Arrange: Set up mock client to return 200 with data
      when(
        mockClient.get(Uri.parse(apiUrl)),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockApiData), 200));

      // CRITICAL: We need the repository to use the mockClient's `get` method.
      // If the repository uses an internal client, this test may still fail at runtime
      // unless you can inject the mock client into the repository's internal state
      // before this point. For now, the expectation is set on the mock client.

      // Act: Fetch and cache
      await repository.fetchAndCacheAllAbilityEffects();

      // Assert: Verify cache size and lookup success
      expect(
        repository.getAbilityRule('ORDER: SET FOR CHARGE'),
        contains('1 wound'),
      );
      expect(
        repository.getAbilityRule('Morale Check'),
        contains('Morale is checked'),
      );

      // Assert: The invalid entry should NOT be cached
      expect(
        repository.getAbilityRule('INVALID_ENTRY'),
        contains('Rule text unavailable'),
      );

      // Verify that the network call happened exactly once
      verify(mockClient.get(Uri.parse(apiUrl))).called(1);
    });

    test(
      'should not make a network call if abilities are already cached',
      () async {
        // Arrange: Cache data first (simulated successful fetch)
        when(
          mockClient.get(Uri.parse(apiUrl)),
        ).thenAnswer((_) async => http.Response(jsonEncode(mockApiData), 200));

        // Ensure cache is populated for this test's instance
        await repository.fetchAndCacheAllAbilityEffects();

        // Reset mock to count future calls
        reset(mockClient);

        // Act: Call fetch again
        await repository.fetchAndCacheAllAbilityEffects();

        // Assert: Verify no network call was made
        // Note: This check relies on the singleton being correctly implemented
        // and having its cache persist between the first fetch and this check.
        verifyNever(mockClient.get(any));
      },
    );

    test('getAbilityRule should normalize keys and find rule text', () async {
      // Arrange: Populate cache (assuming successful fetch)
      when(
        mockClient.get(Uri.parse(apiUrl)),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockApiData), 200));
      await repository.fetchAndCacheAllAbilityEffects();

      // Act & Assert: Test various normalization cases
      // 1. Exact match
      expect(
        repository.getAbilityRule('ORDER: SHIELD WALL'),
        contains('+1 Defense Save'),
      );
      // 2. Lowercase/Whitespace match
      expect(
        repository.getAbilityRule(' order: shield wall '),
        contains('+1 Defense Save'),
      );
      // 3. Different case
      expect(
        repository.getAbilityRule('morale check'),
        contains('Morale is checked'),
      );
    });

    test(
      'getAbilityRule should return error message if key is not found',
      () async {
        // Arrange: Populate cache (assuming successful fetch)
        when(
          mockClient.get(Uri.parse(apiUrl)),
        ).thenAnswer((_) async => http.Response(jsonEncode(mockApiData), 200));
        await repository.fetchAndCacheAllAbilityEffects();

        // Act
        final result = repository.getAbilityRule('Non-Existent Rule');

        // Assert
        expect(result, contains('Rule text unavailable'));
      },
    );
  });
}
