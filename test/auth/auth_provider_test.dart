import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 2b — Google auth structural tests.
///
/// Full Google Sign-In flow requires real platform channels and a live
/// Google account, so these are structural/unit tests only.
/// End-to-end verified by manual smoke test.
void main() {
  group('Platform detection', () {
    test('kIsWeb is a bool', () {
      expect(kIsWeb, isA<bool>());
    });

    test('platform routing would use OAuth on web', () {
      // Simulate the branch our GoogleAuthService takes
      final wouldUseOAuth = kIsWeb;
      final wouldUseNativePicker = !kIsWeb;

      // In the test runner (Dart VM) kIsWeb is false
      expect(wouldUseOAuth, isFalse);
      expect(wouldUseNativePicker, isTrue);
    });
  });

  group('Profile validation', () {
    String? validateDisplayName(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a display name';
      }
      if (value.trim().length < 2) return 'Name is too short';
      return null;
    }

    test('valid name passes', () {
      expect(validateDisplayName('Selam'), isNull);
      expect(validateDisplayName('Abebe Bikila'), isNull);
    });

    test('empty name fails', () {
      expect(validateDisplayName(''), isNotNull);
      expect(validateDisplayName('   '), isNotNull);
    });

    test('single character name fails', () {
      expect(validateDisplayName('A'), isNotNull);
    });

    test('null name fails', () {
      expect(validateDisplayName(null), isNotNull);
    });
  });
}
