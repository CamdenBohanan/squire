import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:squire/data/model/Army_list/Army_unit_data.dart';

class UnitDetailsService {
  final String _baseUrl = 'http://127.0.0.1:8080';
  final http.Client _client; // 1. Client instance stored here

  // 2. Constructor modified for Dependency Injection (DI)
  UnitDetailsService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches detailed stat blocks for a list of unit/attachment names from the backend.
  Future<List<ArmyUnitData>> fetchUnitDetails(
    String faction,
    List<String> unitNames,
  ) async {
    final url = Uri.parse('$_baseUrl/api/units/details');

    final body = jsonEncode({'faction': faction, 'names': unitNames});

    if (kDebugMode) {
      print('--- NETWORK REQUEST START ---');
      print('Attempting POST to: $url');
      print('Request Body: $body');
      print('---------------------------');
    }

    try {
      // 3. Use the injected client for the request
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        // Successful parsing logic...
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<ArmyUnitData> results = [];

        data.forEach((role, list) {
          if (list is List) {
            for (final json in list) {
              try {
                // Assuming ArmyUnitData.fromJson exists and works
                results.add(ArmyUnitData.fromJson(json));
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing ArmyUnitData for $role: $e');
                }
              }
            }
          }
        });

        if (kDebugMode) {
          print(
            'Successfully fetched and parsed ${results.length} unit details.',
          );
        }

        return results;
      } else {
        final errorBody = response.body;
        if (kDebugMode) {
          print(
            'Server responded with non-200 status: ${response.statusCode}. Body: $errorBody',
          );
        }
        throw Exception(
          'Failed to load unit details. Status: ${response.statusCode}. Error: $errorBody',
        );
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print(
          '🛑 FATAL NETWORK ERROR: Failed to connect to $_baseUrl. Error: $e',
        );
        print('STACKTRACE: $stacktrace');
      }
      rethrow;
    }
  }
}
