import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; // Necessary for network requests

final String _apiHost = 'http://127.0.0.1:8080';

class AbilityRepository {
  // Private singleton setup
  AbilityRepository._internal();
  static final AbilityRepository _instance = AbilityRepository._internal();
  factory AbilityRepository() => _instance;

  // Cache for the ability effects once fetched
  Map<String, dynamic> _abilitiesCache = {};

  // Utility to standardize a raw ability name for consistent lookups.
  // CRITICAL FIX: Only convert to uppercase and trim. DO NOT remove prefixes,
  // as the backend keys (e.g., "ORDER: SET FOR CHARGE") include them.
  String _normalizeAbilityName(String rawName) {
    if (rawName.isEmpty) return '';
    return rawName.toUpperCase().trim();
  }

  /// Fetches the entire map of ability name -> effects from the REST API at /abilities
  /// and caches it. This should be called once on app startup or data load.
  Future<void> fetchAndCacheAllAbilityEffects() async {
    if (_abilitiesCache.isNotEmpty) return; // Already cached

    final apiUrl = '$_apiHost/abilities';
    if (kDebugMode) {
      print('Attempting GET to fetch abilities from: $apiUrl');
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);

        if (jsonBody is List && jsonBody.isNotEmpty) {
          final Map<String, dynamic> abilityDoc =
              jsonBody.first as Map<String, dynamic>;
          final Map<String, dynamic> tempAbilitiesMap = {};

          abilityDoc.forEach((name, value) {
            if (name == '_id') return;

            // Store the rule under its standardized, clean name (e.g., "ORDER: SET FOR CHARGE")
            final standardizedKey = _normalizeAbilityName(name);

            if (value is Map<String, dynamic>) {
              final ruleValue = value['effect'] ?? value['rule'];
              String? ruleText;

              if (ruleValue is List) {
                // Join list elements with a newline character (\n) to preserve formatting
                ruleText = ruleValue.map((e) => e.toString()).join('\n');
              } else if (ruleValue != null) {
                ruleText = ruleValue.toString();
              }

              if (ruleText != null &&
                  ruleText.isNotEmpty &&
                  standardizedKey.isNotEmpty) {
                // Store the rule under the standardized key.
                tempAbilitiesMap[standardizedKey] = ruleText;
              } else if (kDebugMode) {
                print(
                  'Warning: Ability value missing rule/effect or standardized key is empty for $name',
                );
              }
            }
          });

          _abilitiesCache = tempAbilitiesMap;
          if (kDebugMode) {
            print(
              'Successfully fetched and parsed and cached ${_abilitiesCache.length} common abilities.',
            );
          }
        }
      } else if (kDebugMode) {
        print('Error fetching abilities. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network error during ability fetch: $e');
      }
    }
  }

  /// Retrieves the rule text for a given raw ability name by normalizing the name
  /// and looking it up in the cache.
  ///
  /// **Your UI or Unit model must use this method.**
  String getAbilityRule(String rawAbilityName) {
    if (_abilitiesCache.isEmpty) {
      return 'Loading rules...';
    }

    // 1. Normalize the raw name from the unit data to match the cache key format
    final normalizedKey = _normalizeAbilityName(rawAbilityName);

    // 2. Look up the rule text using the normalized key
    final rule = _abilitiesCache[normalizedKey];

    if (kDebugMode) {
      print(
        'Attempting lookup for raw: "$rawAbilityName" | normalized: "$normalizedKey" | Result Found: ${rule != null}',
      );
    }

    // 3. Return the rule text, or a helpful error message if not found.
    return rule ??
        'Rule text unavailable or not found in database for "$rawAbilityName".';
  }
}
