import 'package:flutter/material.dart';
import 'package:bookswap/core/supabase_client.dart';

/// Placeholder home screen for Stage 1.
///
/// Shows a live Supabase connection status check.
/// This screen will be replaced by the real home/browse screen in Stage 4.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _ConnectionStatus _status = _ConnectionStatus.checking;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      // Ping the cities table — a lightweight query that proves DB connectivity.
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
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon placeholder
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
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ሀ — Free book swaps, city to city',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            _buildStatusWidget(context),
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
              Text(
                'Connecting to Supabase…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
            label: 'Connection failed — check keys',
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
