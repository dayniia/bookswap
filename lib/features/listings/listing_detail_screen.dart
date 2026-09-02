import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/features/listings/listings_provider.dart';
import 'package:bookswap/features/swaps/swap_provider.dart';

/// Full-detail view of a single listing, plus a stub swap-request button.
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(listingDetailProvider(listingId));

    return Scaffold(
      body: detail.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Listing not found'));
          }
          return _ListingBody(listing: listing);
        },
      ),
    );
  }
}

class _ListingBody extends ConsumerWidget {
  const _ListingBody({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photos = (listing['photo_urls'] as List?)?.cast<String>() ?? [];
    final condition = listing['condition'] as String? ?? 'good';
    final language = listing['language'] as String? ?? 'en';
    final ownerName =
        (listing['profiles'] as Map?)?['display_name'] as String? ?? 'Someone';
    final ownerArea =
        (listing['profiles'] as Map?)?['area_note'] as String?;
    final cityName =
        (listing['cities'] as Map?)?['name'] as String? ?? 'Ethiopia';

    final isOwner = SupabaseClientProvider.client.auth.currentUser?.id ==
        listing['owner_id'];

    return CustomScrollView(
      slivers: [
        // ── Photo header ─────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: photos.isNotEmpty ? 280 : 120,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isNotEmpty
                ? PageView.builder(
                    itemCount: photos.length,
                    itemBuilder: (ctx, i) => CachedNetworkImage(
                      imageUrl: photos[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          color: colors.surfaceContainerHighest),
                    ),
                  )
                : Container(
                    color: colors.primaryContainer,
                    child: Icon(Icons.menu_book_rounded,
                        size: 80, color: colors.onPrimaryContainer),
                  ),
          ),
        ),

        // ── Content ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  listing['title'] as String? ?? 'Untitled',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((listing['author'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'by ${listing['author']}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.star_outline_rounded,
                      label: conditionLabels[condition] ?? condition,
                    ),
                    _InfoChip(
                      icon: Icons.translate_rounded,
                      label: languageLabels[language] ?? language,
                    ),
                    _InfoChip(
                      icon: Icons.location_city_rounded,
                      label: cityName,
                    ),
                    if (ownerArea != null)
                      _InfoChip(
                        icon: Icons.place_outlined,
                        label: ownerArea,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                if ((listing['description'] as String?)?.isNotEmpty == true) ...[
                  Text('About this book',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    listing['description'] as String,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                ],

                // Owner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ownerName,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Listing owner',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Swap request button
                if (!isOwner)
                  _RequestSwapButton(
                    listingId: listing['id'] as String,
                    ownerId: listing['owner_id'] as String,
                    ref: ref,
                  ),

                if (isOwner)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove listing?'),
                          content: const Text(
                              'This will mark your listing as removed.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        try {
                          await SupabaseClientProvider.client
                              .from('listings')
                              .update({'status': 'removed'})
                              .eq('id', listing['id'] as String);
                          // Refresh browse grid
                          ref.invalidate(listingsProvider);
                          if (context.mounted) context.pop();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to remove: $e'),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove listing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request swap button — shows existing status or opens message dialog
// ─────────────────────────────────────────────────────────────────────────────

class _RequestSwapButton extends ConsumerWidget {
  const _RequestSwapButton({
    required this.listingId,
    required this.ownerId,
    required this.ref,
  });

  final String listingId;
  final String ownerId;
  // ignore: unused_field
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(existingRequestProvider(listingId));

    return existing.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (request) {
        final status = request?['status'] as String?;

        // Already requested — show status chip
        if (status != null && status != 'cancelled') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor(context, status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _statusColor(context, status).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_statusIcon(status),
                    color: _statusColor(context, status), size: 18),
                const SizedBox(width: 8),
                Text(
                  _statusText(status),
                  style: TextStyle(
                    color: _statusColor(context, status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        // No active request — show request button
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showRequestDialog(context, ref),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text(
              'Request a swap',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRequestDialog(BuildContext context, WidgetRef ref) async {
    final msgCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request a swap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The owner will see your request and can accept or decline. '
              'Add an optional message:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. "I have a similar book to offer…"',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send request')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await SwapService.sendRequest(
          listingId: listingId,
          ownerId: ownerId,
          message: msgCtrl.text.trim(),
        );
        ref.invalidate(existingRequestProvider(listingId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Swap request sent! ✓'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send request: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      msgCtrl.dispose();
    }
  }

  Color _statusColor(BuildContext ctx, String status) => switch (status) {
        'accepted' => Colors.green.shade700,
        'declined' => Theme.of(ctx).colorScheme.error,
        _ => Colors.orange.shade700,
      };

  IconData _statusIcon(String status) => switch (status) {
        'accepted' => Icons.check_circle_outline_rounded,
        'declined' => Icons.cancel_outlined,
        _ => Icons.hourglass_empty_rounded,
      };

  String _statusText(String status) => switch (status) {
        'accepted' => 'Swap accepted!',
        'declined' => 'Request declined',
        _ => 'Request pending…',
      };
}

