import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bookswap/features/listings/listings_provider.dart';

/// A card in the browse grid showing a single listing's key info.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final Map<String, dynamic> listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final photos = (listing['photo_urls'] as List?)?.cast<String>() ?? [];
    final hasPhoto = photos.isNotEmpty;
    final cityName =
        (listing['cities'] as Map?)?['name'] as String? ?? 'Ethiopia';
    final condition = listing['condition'] as String? ?? 'good';
    final conditionLabel = conditionLabels[condition] ?? condition;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ────────────────────────────────────────────────
            Expanded(
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: photos.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => _PhotoPlaceholder(),
                      errorWidget: (_, __, ___) => _PhotoPlaceholder(),
                    )
                  : _PhotoPlaceholder(),
            ),

            // ── Info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing['title'] as String? ?? 'Untitled',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((listing['author'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      listing['author'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ConditionChip(label: conditionLabel, condition: condition),
                      const Spacer(),
                      Icon(Icons.location_on_outlined,
                          size: 12, color: colors.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          cityName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.label, required this.condition});
  final String label;
  final String condition;

  Color _color(BuildContext context) {
    return switch (condition) {
      'new' => Colors.green.shade700,
      'like_new' => Colors.teal.shade600,
      'good' => Colors.blue.shade700,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
