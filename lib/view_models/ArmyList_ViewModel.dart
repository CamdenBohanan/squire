import 'package:flutter/material.dart';
import 'package:squire/data/services/army_list_parser.dart';
import 'package:squire/data/model/Army_list/Army_unit_data.dart';
import 'package:squire/data/repositories/unit_repository.dart';

// Example ViewModel class (in lib/viewmodel/unit_portrait_viewmodel.dart)
class UnitPortraitViewModel extends ChangeNotifier {
  final String _serverBaseUrl = 'http://localhost:8080';

  // Assuming this list is populated after the API call
  List<ArmyUnitData> unitList = [];

  // Method to construct the image URL for the View
  String getPortraitUrl(String unitId) {
    // We assume all images are .png for consistency
    return '$_serverBaseUrl/portraits/$unitId.png';
  }
}
