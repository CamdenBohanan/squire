import 'package:flutter/foundation.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart';
import 'package:squire/data/services/unit_details_service.dart';
import 'package:squire/data/services/army_list_parser.dart';

class UnitRepository {
  final UnitDetailsService _detailsService;
  final ArmyListParser _parserService;

  UnitRepository(this._detailsService, this._parserService);

  // Helper: Simple, robust normalization: remove spaces, punctuation, convert to lowercase
  String _normalizeNameForComparison(String name) {
    if (name.isEmpty) return '';
    // Remove all non-word characters (including spaces, punctuation, hyphens, etc.)
    return name.toLowerCase().replaceAll(RegExp(r'[\s\W_]+'), '');
  }

  // Helper: Safely generate the unit's full name for comparison
  String _getUnitFullName(ArmyUnitData data) {
    // FIX 1: Use null-aware access (?.) and coalescing (??) to safely call trim()
    final name = data.name?.trim() ?? '';
    final title = (data.title ?? '').trim();

    if (title.isNotEmpty) {
      return '$name - $title';
    }

    return name;
  }

  Future<ListPa> parseListAndFetchDetails(String rawArmyListText) async {
    // 1. Parse the raw text to get unit names and faction
    final ListPa parsedList = _parserService.parseArmyList(rawArmyListText);

    // 2. Identify and sanitize all unique unit names
    final Set<String> uniqueNamesToFetch = {};

    // 2.1 Commander name
    String commanderName = parsedList.commanderName.trim();
    if (commanderName.isNotEmpty) {
      uniqueNamesToFetch.add(commanderName);
    }

    // 2.2 Combat Units
    for (final unit in parsedList.combatUnits) {
      String unitName = unit.unitName.trim();
      if (unitName.isNotEmpty) {
        uniqueNamesToFetch.add(unitName);
      }
      String attachmentName = unit.attachmentName?.trim() ?? '';
      if (attachmentName.isNotEmpty) {
        uniqueNamesToFetch.add(attachmentName);
      }
    }

    // 2.3 NCUs
    for (final ncu in parsedList.ncus) {
      String ncuName = ncu.unitName.trim();
      if (ncuName.isNotEmpty) {
        uniqueNamesToFetch.add(ncuName);
      }
    }

    // CRITICAL SAFETY CHECK: If the set is empty, do not proceed with the API call.
    if (uniqueNamesToFetch.isEmpty) {
      if (kDebugMode) {
        print(
          'Warning: No unique unit names found after parsing and sanitizing. Skipping API fetch.',
        );
      }
      // Return the original list with null details, preventing runtime errors.
      return parsedList.copyWith(
        commanderDetails: null,
        combatUnits: parsedList.combatUnits
            .map((u) => u.copyWith(unitDetails: null, attachmentDetails: null))
            .toList(),
        ncus: parsedList.ncus
            .map((u) => u.copyWith(unitDetails: null))
            .toList(),
      );
    }

    // 3. Fetch details for the extracted unit names
    List<ArmyUnitData> unitDetails;
    try {
      // Convert the Set<String> to a List<String> using .toList()
      unitDetails = await _detailsService.fetchUnitDetails(
        parsedList.faction,
        uniqueNamesToFetch.toList(),
      );
      // Filter out any null elements returned in the list array
      unitDetails = unitDetails.where((data) => data != null).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error during API fetch: $e');
      }
      // If the fetch failed, proceed with no details (empty list)
      unitDetails = [];
    }

    if (kDebugMode) {
      print('Total API details fetched: ${unitDetails.length}');
      for (var detail in unitDetails) {
        print(
          '  -> Available API Name: ${_getUnitFullName(detail)} (ID: ${detail.id})',
        );
      }
    }

    // 4. Map fetched details back into the ListPa structure
    List<UnitEntry> detailedCombatUnits = [];
    List<UnitEntry> detailedNCUs = [];

    // The critical function for matching parsed names to fetched API data
    ArmyUnitData? findDetails(String name) {
      if (name.isEmpty) return null;
      final normalizedSearchKey = _normalizeNameForComparison(name);

      if (kDebugMode) {
        print(
          '\n--- Searching for unit: "$name" (Key: $normalizedSearchKey) ---',
        );
      }

      for (final data in unitDetails) {
        final dataFullName = _getUnitFullName(data);

        // FIX 2: Use null-aware access (?.) and coalescing (??) here as well.
        final dataBaseName = data.name?.trim() ?? '';

        // Normalize the names from the fetched data
        final normalizedDataFullName = _normalizeNameForComparison(
          dataFullName,
        );
        final normalizedDataBaseName = _normalizeNameForComparison(
          dataBaseName,
        );

        // 1. BEST MATCH: Exact match on the FULL normalized name
        if (normalizedDataFullName == normalizedSearchKey) {
          if (kDebugMode) {
            print(
              '✅ Matched by FULL Normalized Name: $dataFullName (ID: ${data.id})',
            );
          }
          return data;
        }

        // 2. SECOND BEST MATCH: Exact match on the BASE normalized name
        if (normalizedDataBaseName.isNotEmpty &&
            normalizedDataBaseName == normalizedSearchKey) {
          if (kDebugMode) {
            print(
              '✅ Matched by BASE Normalized Name: $dataBaseName (ID: ${data.id})',
            );
          }
          return data;
        }

        // 3. Fallback: Search key CONTAINS the normalized base name
        // We use a length check (>5) to prevent matching trivial partial strings.
        if (normalizedDataBaseName.isNotEmpty &&
            normalizedSearchKey.contains(normalizedDataBaseName) &&
            normalizedDataBaseName.length > 5) {
          if (kDebugMode) {
            print(
              '✅ Matched by CONTAINS (Fallback): $dataFullName (ID: ${data.id})',
            );
          }
          return data;
        }
      }

      if (kDebugMode) {
        print(
          '❌ FAILED to find details for: "$name". Stat data will be missing.',
        );
      }
      return null;
    }

    // 4.1. Get Commander Details
    ArmyUnitData? commanderDetail;
    if (parsedList.commanderName.isNotEmpty) {
      commanderDetail = findDetails(parsedList.commanderName);
    }

    // 4.2. Map Combat Units
    for (final unit in parsedList.combatUnits) {
      final unitDetail = findDetails(unit.unitName);

      ArmyUnitData? attachDetail;

      // Find the detail for the attachment name (nullable)
      if (unit.attachmentName != null) {
        attachDetail = findDetails(unit.attachmentName!);
      }

      detailedCombatUnits.add(
        unit.copyWith(unitDetails: unitDetail, attachmentDetails: attachDetail),
      );
    }

    // 4.3. Map NCUs
    for (final ncu in parsedList.ncus) {
      final ncuDetail = findDetails(ncu.unitName);
      detailedNCUs.add(ncu.copyWith(unitDetails: ncuDetail));
    }

    // 5. Final check and return
    return parsedList.copyWith(
      commanderDetails: commanderDetail,
      combatUnits: detailedCombatUnits,
      ncus: detailedNCUs,
    );
  }
}
