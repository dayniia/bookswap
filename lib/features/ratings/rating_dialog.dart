import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/features/ratings/rating_provider.dart';
import 'package:bookswap/features/swaps/swap_provider.dart';

/// Shows a star-rating dialog and submits the rating.
/// Call via [RatingDialog.show].
class RatingDialog extends ConsumerStatefulWidget {
  const RatingDialog({
    super.key,
    required this.swapRequestId,
    required this.ratedUserId,
    required this.ratedUserName,
  });

  final String swapRequestId;
  final String ratedUserId;
  final String ratedUserName;

  static Future<void> show(
    BuildContext context, {
    required String swapRequestId,
    required String ratedUserId,
    required String ratedUserName,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        swapRequestId: swapRequestId,
        ratedUserId: ratedUserId,
        ratedUserName: ratedUserName,
      ),
    );
  }

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await RatingService.submitRating(
        swapRequestId: widget.swapRequestId,
        ratedUserId: widget.ratedUserId,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
      );
      ref.invalidate(hasRatedProvider(widget.swapRequestId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Text('Rate ${widget.ratedUserName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How was the swap experience?'),
          const SizedBox(height: 16),

          // Star selector
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _stars = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      star <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: star <= _stars
                          ? Colors.amber.shade600
                          : colors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_stars > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                _starLabel(_stars),
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Optional comment
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Optional comment…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  String _starLabel(int stars) => switch (stars) {
        1 => '😕 Poor',
        2 => '😐 Fair',
        3 => '🙂 Good',
        4 => '😊 Great',
        _ => '🤩 Excellent!',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact star display (read-only, for browse/detail screens)
// ─────────────────────────────────────────────────────────────────────────────

/// Displays ★ N.N (K reviews) for a given profile.
class StarRatingDisplay extends ConsumerWidget {
  const StarRatingDisplay({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(profileRatingProvider(profileId));
    return rating.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        if (r.count == 0) {
          return Text('No ratings yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ));
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded,
                size: 16, color: Colors.amber.shade600),
            const SizedBox(width: 3),
            Text(
              '${r.avg.toStringAsFixed(1)} (${r.count})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        );
      },
    );
  }
}
