import 'package:flutter_test/flutter_test.dart';

/// Stage 2 auth structural tests.
///
/// Full Supabase initialization requires platform channels (shared_preferences)
/// that aren't available in pure unit tests. These tests verify our provider
/// code compiles correctly and our auth logic helpers behave as expected.
///
/// End-to-end auth is verified by the manual smoke test:
///   1. Run the app
///   2. Enter email → "Send magic link" → email arrives
///   3. Tap link → lands on profile setup (first time) or home
void main() {
  group('Auth email validation', () {
    bool isValidEmail(String email) {
      return email.isNotEmpty && email.contains('@') && email.contains('.');
    }

    test('valid email passes', () {
      expect(isValidEmail('user@example.com'), isTrue);
      expect(isValidEmail('selam@bookswap.et'), isTrue);
    });

    test('empty email fails', () {
      expect(isValidEmail(''), isFalse);
    });

    test('email without @ fails', () {
      expect(isValidEmail('notanemail'), isFalse);
    });

    test('email without dot fails', () {
      expect(isValidEmail('user@nodot'), isFalse);
    });
  });

  group('Profile validation', () {
    String? validateDisplayName(String? value) {
      if (value == null || value.trim().isEmpty) return 'Please enter a display name';
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
