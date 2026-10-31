import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/place_order.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/presentation/day_tabs.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({required this.service, required this.provider, super.key});

  final CommunityService service;
  final ServiceProvider provider;

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  final Map<String, int> _quantities = {};
  DateTime? _selectedDay;
  String? _error;
  bool _placing = false;

  int _quantityOf(String itemId) => _quantities[itemId] ?? 0;

  int _totalCents(List<MenuItem> items) {
    var total = 0;
    for (final item in items) {
      total += item.priceCents * _quantityOf(item.id);
    }
    return total;
  }

  Future<void> _place(List<MenuItem> items) async {
    final userId = ref.read(sessionProvider)?.id;
    if (userId == null || _placing) {
      return;
    }
    final lines = [
      for (final item in items)
        if (_quantityOf(item.id) > 0)
          OrderRequestLine(itemId: item.id, quantity: _quantityOf(item.id)),
    ];
    setState(() {
      _placing = true;
      _error = null;
    });
    final result = await ref
        .read(placeOrderProvider)
        .call(userId: userId, serviceId: widget.service.id, lines: lines);
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        invalidateBookingViews(ref);
        context.go('/activity');
      case Err(:final error):
        setState(() {
          _placing = false;
          _error = orderFailureMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(
      menuProvider(
        MenuQuery(serviceId: widget.service.id, providerId: widget.provider.id),
      ),
    );
    final offering = ref
        .watch(
          offeringProvider(
            OfferingQuery(
              providerId: widget.provider.id,
              serviceId: widget.service.id,
            ),
          ),
        )
        .asData
        ?.value;
    final openDays = offering?.openWeekdays ?? const <int>[];
    final now = ref.watch(clockProvider).now();
    final days = [
      for (final day in menuDays(
        now,
        offering?.bookingWindow ?? const BookingWindow(),
      ))
        if (openDays.isEmpty || openDays.contains(day.weekday)) day,
    ];
    final selectedDay = days.isEmpty
        ? null
        : (_selectedDay != null && days.contains(_selectedDay)
              ? _selectedDay
              : days.first);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.displayName)),
      body: days.isEmpty
          ? const Center(child: Text('No open days in this booking window.'))
          : AsyncView(
              value: menu,
              data: (items) {
                final day = selectedDay!;
                final dayItems = [
                  for (final item in items)
                    if (item.isAvailableAt(
                      DateTime(day.year, day.month, day.day, 12),
                    ))
                      item,
                ];
                final total = _totalCents(dayItems);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    DayTabs(
                      days: days,
                      selected: selectedDay,
                      onSelected: (day) => setState(() => _selectedDay = day),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offering?.name ?? widget.provider.displayName,
                            style: textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            offering?.description.isNotEmpty == true
                                ? offering!.description
                                : widget.provider.bio,
                            style: textTheme.bodySmall,
                          ),
                          if (offering != null &&
                              offering.hoursOn(day.weekday).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Open ${formatOpeningHours(offering.hoursOn(day.weekday))}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: dayItems.isEmpty
                          ? const Center(
                              child: Text('Nothing is on the menu this day.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: dayItems.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = dayItems[index];
                                final quantity = _quantityOf(item.id);
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: textTheme.bodySmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                formatPrice(item.priceCents),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey(
                                            'item-${item.id}-remove',
                                          ),
                                          onPressed: quantity == 0
                                              ? null
                                              : () => setState(() {
                                                  _quantities[item.id] =
                                                      quantity - 1;
                                                }),
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Text(
                                          '$quantity',
                                          key: ValueKey('item-${item.id}-qty'),
                                        ),
                                        IconButton(
                                          key: ValueKey('item-${item.id}-add'),
                                          onPressed: () => setState(() {
                                            _quantities[item.id] = quantity + 1;
                                          }),
                                          icon: const Icon(Icons.add),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          _error!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Padding(
                      padding: pagePadding,
                      child: FilledButton(
                        key: const Key('place-order'),
                        onPressed: total == 0 || _placing
                            ? null
                            : () => _place(dayItems),
                        child: Text(
                          _placing
                              ? 'Placing order…'
                              : 'Place order · ${formatPrice(total)}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
