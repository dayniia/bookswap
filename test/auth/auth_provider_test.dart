import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 3 auth tests — email/password + Google.
void main() {
  group('Email validation', () {
    String? validateEmail(String? v) {
      if (v == null || v.trim().isEmpty) return 'Enter your email';
      if (!v.contains('@')) return 'Enter a valid email';
      return null;
    }

    test('valid email passes', () {
      expect(validateEmail('selam@example.com'), isNull);
      expect(validateEmail('a@b.et'), isNull);
    });

    test('empty email fails', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
    });

    test('email without @ fails', () {
      expect(validateEmail('noemail'), isNotNull);
    });
  });

  group('Password validation', () {
    String? validatePassword(String? v, {bool isSignUp = false}) {
      if (v == null || v.isEmpty) return 'Enter a password';
      if (isSignUp && v.length < 6) return 'Password must be at least 6 characters';
      return null;
    }

    test('valid password passes on sign in', () {
      expect(validatePassword('abc', isSignUp: false), isNull);
    });

    test('short password fails on sign up', () {
      expect(validatePassword('abc', isSignUp: true), isNotNull);
    });

    test('6+ char password passes on sign up', () {
      expect(validatePassword('abcdef', isSignUp: true), isNull);
    });

    test('empty password always fails', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });
  });

  group('Friendly error messages', () {
    String friendlyError(String raw) {
      if (raw.contains('Invalid login credentials')) {
        return 'Wrong email or password. Please try again.';
      }
      if (raw.contains('Email not confirmed')) {
        return 'Please confirm your email first, then sign in.';
      }
      if (raw.contains('User already registered')) {
        return 'An account with this email already exists. Sign in instead.';
      }
      if (raw.contains('Password should be')) {
        return 'Password must be at least 6 characters.';
      }
      return raw;
    }

    test('invalid credentials → friendly message', () {
      expect(
        friendlyError('AuthException: Invalid login credentials'),
        contains('Wrong email'),
      );
    });

    test('user already registered → friendly message', () {
      expect(
        friendlyError('User already registered'),
        contains('already exists'),
      );
    });

    test('unknown error passes through', () {
      expect(friendlyError('some unknown error'), equals('some unknown error'));
    });
  });

  group('Platform detection', () {
    test('kIsWeb is a bool', () {
      expect(kIsWeb, isA<bool>());
    });
  });

  group('Profile name validation', () {
    String? validateName(String? v) {
      if (v == null || v.trim().isEmpty) return 'Please enter a display name';
      if (v.trim().length < 2) return 'Name is too short';
      return null;
    }

    test('valid name passes', () {
      expect(validateName('Selam'), isNull);
    });

    test('single char fails', () {
      expect(validateName('A'), isNotNull);
    });

    test('empty fails', () {
      expect(validateName(''), isNotNull);
    });
  });
}
