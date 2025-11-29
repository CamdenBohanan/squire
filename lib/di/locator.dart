import 'package:get_it/get_it.dart';
import 'package:squire/data/services/army_list_parser.dart';
import 'package:squire/data/services/unit_details_service.dart';
import 'package:squire/data/repositories/unit_repository.dart';
import 'package:squire/data/repositories/Ability_Repository.dart'; // REQUIRED IMPORT

final locator = GetIt.instance;

void setupLocator() {
  // --- Services ---
  locator.registerLazySingleton<ArmyListParser>(() => ArmyListParser());
  locator.registerLazySingleton<UnitDetailsService>(() => UnitDetailsService());

  // --- Register the Ability Repository (CRITICAL FIX) ---
  locator.registerLazySingleton<AbilityRepository>(() => AbilityRepository());

  // --- Repositories ---
  locator.registerLazySingleton<UnitRepository>(
    () => UnitRepository(
      locator<UnitDetailsService>(),
      locator<ArmyListParser>(),
    ),
  );
}
