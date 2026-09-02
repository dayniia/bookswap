import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswap/features/auth/auth_provider.dart';
import 'package:bookswap/features/auth/auth_screen.dart';
import 'package:bookswap/features/auth/profile_setup_screen.dart';
import 'package:bookswap/features/listings/add_listing_screen.dart';
import 'package:bookswap/features/listings/browse_screen.dart';
import 'package:bookswap/features/listings/listing_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final session = authState.value;
      final isSignedIn = session != null;
      final loc = state.matchedLocation;
      final isOnAuth = loc == '/auth';

      if (!isSignedIn && !isOnAuth) return '/auth';
      if (isSignedIn && isOnAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const _AuthGatedHome(),
      ),
      GoRoute(
        path: '/listings/add',
        builder: (_, __) => const AddListingScreen(),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (_, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Checks if the signed-in user still needs profile setup; if so, redirects.
class _AuthGatedHome extends ConsumerWidget {
  const _AuthGatedHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsSetup = ref.watch(needsProfileSetupProvider);

    return needsSetup.when(
      data: (needs) {
        if (needs) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile-setup');
          });
          return const SizedBox.shrink();
        }
        return const BrowseScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const BrowseScreen(),
    );
  }
}
