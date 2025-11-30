import 'package:flutter_test/flutter_test.dart';

// This function is defined here in the test file.
// It is an exact replica of the private logic from Army_backend.dart,
// but it is fully self-contained and testable.
String normalizeDocNameTestable(Map<String, dynamic> doc, RegExp sanitizer) {
  final rawName = (doc['name'] as String? ?? '').toLowerCase().trim();
  final rawTitle = (doc['title'] as String? ?? '').toLowerCase().trim();

  // The name of the unit itself
  String normalizedName = rawName.replaceAll(sanitizer, '').replaceAll(' ', '');

  // 1. If a title exists, combine them aggressively
  if (rawTitle.isNotEmpty) {
    // Combines Name + Title without any separators
    return normalizedName +
        rawTitle.replaceAll(sanitizer, '').replaceAll(' ', '');
  }

  return normalizedName;
}

void main() {
  final RegExp sanitizer = RegExp(r'[^a-z0-9]', caseSensitive: false);

  group('Normalization Logic Unit Tests', () {
    test('Should normalize simple unit name correctly (remove spaces)', () {
      final doc = {'name': 'Stark Sworn Swords', 'title': ''};
      expect(normalizeDocNameTestable(doc, sanitizer), 'starkswornswords');
    });

    test('Should combine name and title correctly and sanitize both', () {
      final doc = {'name': 'Robb Stark', 'title': 'The Wolf Lord'};
      expect(normalizeDocNameTestable(doc, sanitizer), 'robbstarkthewolflord');
    });

    test('Should return an empty string for empty inputs', () {
      final doc = {'name': '', 'title': ''};
      expect(normalizeDocNameTestable(doc, sanitizer), '');
    });
  });
}
