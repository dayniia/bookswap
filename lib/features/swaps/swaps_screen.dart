import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswap/features/swaps/swap_provider.dart';

/// Full-page list of incoming and outgoing swap requests.
class SwapsScreen extends ConsumerWidget {
  const SwapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Swaps',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inbox_rounded), text: 'Incoming'),
              Tab(icon: Icon(Icons.outbox_rounded), text: 'Sent'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _IncomingTab(),
            _OutgoingTab(),
          ],
        ),
      ),
    );
  }
}

// ── Incoming ─────────────────────────────────────────────────────────────────

class _IncomingTab extends ConsumerWidget {
  const _IncomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading requests', style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text('$e', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(incomingRequestsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState('No incoming swap requests yet');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(incomingRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _IncomingCard(request: list[i]),
          ),
        );
      },
    );
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = request['status'] as String? ?? 'pending';
    final requesterName =
        (request['requester'] as Map?)?['display_name'] as String? ?? 'Someone';
    final bookTitle =
        (request['book'] as Map?)?['title'] as String? ?? 'a book';
    final message = request['message'] as String?;
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    requesterName.isNotEmpty
                        ? requesterName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(requesterName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('wants "$bookTitle"',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(message,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _updateStatus(context, ref, request['id'] as String, 'declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _updateStatus(context, ref, request['id'] as String, 'accepted'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            if (isAccepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/chat/${request['id']}'
                    '?otherName=${Uri.encodeComponent(requesterName)}'
                    '&book=${Uri.encodeComponent(bookTitle)}',
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Open chat'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await SwapService.updateStatus(id, status);
      ref.invalidate(incomingRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// ── Outgoing ─────────────────────────────────────────────────────────────────

class _OutgoingTab extends ConsumerWidget {
  const _OutgoingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(outgoingRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading requests',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text('$e', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(outgoingRequestsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState("You haven't requested any swaps yet");
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(outgoingRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _OutgoingCard(request: list[i]),
          ),
        );
      },
    );
  }
}

class _OutgoingCard extends ConsumerWidget {
  const _OutgoingCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = request['status'] as String? ?? 'pending';
    final ownerName =
        (request['book_owner'] as Map?)?['display_name'] as String? ?? 'Someone';
    final bookTitle =
        (request['book'] as Map?)?['title'] as String? ?? 'a book';
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"$bookTitle"',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('by $ownerName',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      _cancel(context, ref, request['id'] as String),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel request'),
                ),
              ),
            ],
            if (isAccepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/chat/${request['id']}'
                    '?otherName=${Uri.encodeComponent(ownerName)}'
                    '&book=${Uri.encodeComponent(bookTitle)}',
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Open chat'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, String id) async {
    try {
      await SwapService.updateStatus(id, 'cancelled');
      ref.invalidate(outgoingRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded,
              size: 64,
              color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color _color(BuildContext context) => switch (status) {
        'pending' => Colors.orange.shade700,
        'accepted' => Colors.green.shade700,
        'declined' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        swapStatusLabels[status] ?? status,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
