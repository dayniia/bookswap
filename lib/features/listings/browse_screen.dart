import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswap/features/auth/auth_provider.dart';
import 'package:bookswap/features/listings/listing_card.dart';
import 'package:bookswap/features/listings/listings_provider.dart';

/// Main browse screen — lists all available books with search + filter.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCityId;
  String? _selectedLanguage;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    ref
        .read(listingFilterProvider.notifier)
        .update((f) => f.copyWith(search: value.isEmpty ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final listings = ref.watch(listingsProvider);
    final cities = ref.watch(citiesProvider);
    final session = ref.watch(authSessionProvider).value;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text(
              'BookSwap',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'My swaps',
                onPressed: () => context.push('/swaps'),
              ),
              if (session != null)
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign out',
                  onPressed: () async => AuthService.signOut(),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search by title or author…',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applySearch('');
                        },
                      ),
                  ],
                  onChanged: _applySearch,
                  elevation: const WidgetStatePropertyAll(1),
                ),
              ),
            ),
          ),

          // ── Filter chips ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: cities.when(
                data: (cityList) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Language filter
                    ...languageLabels.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(e.value),
                          selected: _selectedLanguage == e.key,
                          onSelected: (on) {
                            setState(() {
                              _selectedLanguage = on ? e.key : null;
                            });
                            ref
                                .read(listingFilterProvider.notifier)
                                .update((f) => f.copyWith(
                                      language: on ? e.key : null,
                                    ));
                          },
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 16),
                    // City filter
                    ...cityList.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c['name'] as String),
                          selected: _selectedCityId == c['id'],
                          onSelected: (on) {
                            setState(() {
                              _selectedCityId = on ? c['id'] as String : null;
                            });
                            ref
                                .read(listingFilterProvider.notifier)
                                .update((f) => f.copyWith(
                                      cityId: on ? c['id'] as String : null,
                                    ));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Listing grid ────────────────────────────────────────────
          listings.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 64,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No books yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to list a book!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => ListingCard(
                    listing: items[i],
                    onTap: () =>
                        context.push('/listings/${items[i]['id']}'),
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),

      // ── FAB — post a book ───────────────────────────────────────────
      floatingActionButton: session != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/listings/add');
                // Refresh list after returning
                ref.invalidate(listingsProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('List a book'),
            )
          : null,
    );
  }
}
