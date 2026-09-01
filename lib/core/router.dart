import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswap/features/auth/auth_provider.dart';
import 'package:bookswap/features/auth/auth_screen.dart';
import 'package:bookswap/features/auth/profile_setup_screen.dart';
import 'package:bookswap/features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth state changes
  final authState = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final session = authState.value;
      final isSignedIn = session != null;
      final isOnAuth = state.matchedLocation == '/auth';
      final isOnSetup = state.matchedLocation == '/profile-setup';

      // Not signed in → always go to auth
      if (!isSignedIn && !isOnAuth) return '/auth';

      // Signed in → don't linger on auth screen
      if (isSignedIn && isOnAuth) return '/home';

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const _AuthGatedHome(),
      ),
    ],
  );
});

/// Wraps HomeScreen, redirecting to profile-setup if profile not yet created.
class _AuthGatedHome extends ConsumerWidget {
  const _AuthGatedHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsSetup = ref.watch(needsProfileSetupProvider);

    return needsSetup.when(
      data: (needs) {
        if (needs) {
          // Use addPostFrameCallback to avoid navigating during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile-setup');
          });
          return const SizedBox.shrink();
        }
        return const HomeScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const HomeScreen(),
    );
  }
}
