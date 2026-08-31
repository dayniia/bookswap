import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/features/auth/auth_provider.dart';

/// Placeholder home screen for Stage 1 & 2.
///
/// Shows Supabase connection status + signed-in user info.
/// Will be replaced by the real browse screen in Stage 4.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _ConnectionStatus _status = _ConnectionStatus.checking;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      await SupabaseClientProvider.client
          .from('cities')
          .select('name')
          .limit(1);
      if (mounted) setState(() => _status = _ConnectionStatus.connected);
    } catch (e) {
      if (mounted) setState(() => _status = _ConnectionStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('BookSwap Ethiopia'),
        actions: [
          if (session != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
              onPressed: () async {
                await AuthService.signOut();
              },
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'BookSwap Ethiopia',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ሀ — Free book swaps, city to city',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _buildStatusWidget(context),
            if (session != null) ...[
              const SizedBox(height: 24),
              Chip(
                avatar: const Icon(Icons.person_outline_rounded, size: 18),
                label: Text(session.user.email ?? 'Signed in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_status) {
        _ConnectionStatus.checking => Row(
            key: const ValueKey('checking'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Connecting to Supabase…'),
            ],
          ),
        _ConnectionStatus.connected => _StatusChip(
            key: const ValueKey('connected'),
            icon: Icons.check_circle_rounded,
            label: 'Connected ✓',
            color: Colors.green.shade700,
            backgroundColor: Colors.green.shade50,
          ),
        _ConnectionStatus.error => _StatusChip(
            key: const ValueKey('error'),
            icon: Icons.error_rounded,
            label: 'Connection failed',
            color: Colors.red.shade700,
            backgroundColor: Colors.red.shade50,
          ),
      },
    );
  }
}

enum _ConnectionStatus { checking, connected, error }

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
