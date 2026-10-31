import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/profile/domain/car_wash_pricing.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/price_parser.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class ConfigureOfferingPage extends ConsumerStatefulWidget {
  const ConfigureOfferingPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  ConsumerState<ConfigureOfferingPage> createState() =>
      _ConfigureOfferingPageState();
}

class _ConfigureOfferingPageState extends ConsumerState<ConfigureOfferingPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _itemName = TextEditingController();
  final _price = TextEditingController();
  final _weekdayHours = <int>{};
  final _weekendHours = <int>{};
  final _weekdays = <int>{};
  _OpenMode? _mode;
  final _advanceAmount = TextEditingController(text: '0');
  final _openForAmount = TextEditingController(text: '1');
  AdvanceUnit _advanceUnit = AdvanceUnit.hour;
  AdvanceUnit _openForUnit = AdvanceUnit.week;
  bool _autoConfirm = true;
  final _concurrentBookings = TextEditingController(text: '1');
  final _treatments = <_TreatmentDraft>[];
  String? _error;
  bool _saving = false;
  bool _loading = true;
  bool _editing = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadExisting);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _advanceAmount.dispose();
    _openForAmount.dispose();
    _concurrentBookings.dispose();
    _itemName.dispose();
    _price.dispose();
    for (final treatment in _treatments) {
      treatment.dispose();
    }
    super.dispose();
  }

  Widget _hourChoices({
    required String title,
    required String subtitle,
    required String keyPrefix,
    required Set<int> selected,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hour in offeringHourChoices)
              ChoiceChip(
                key: ValueKey('$keyPrefix-$hour'),
                label: Text('${hour.toString().padLeft(2, '0')}:00'),
                selected: selected.contains(hour),
                color: _openChipColor,
                labelStyle: _chipLabel(selected.contains(hour)),
                onSelected: (chosen) {
                  setState(() {
                    if (chosen) {
                      selected.add(hour);
                    } else {
                      selected.remove(hour);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  bool _leadIs(int amount, AdvanceUnit unit) {
    return _advanceUnit == unit &&
        int.tryParse(_advanceAmount.text.trim()) == amount;
  }

  void _setLead(int amount, AdvanceUnit unit) {
    setState(() {
      _advanceUnit = unit;
      _advanceAmount.text = '$amount';
    });
  }

  Widget _bookingWindowSection() {
    final textTheme = Theme.of(context).textTheme;
    final customLead =
        !_leadIs(0, AdvanceUnit.hour) &&
        !_leadIs(1, AdvanceUnit.day) &&
        _advanceUnit != AdvanceUnit.nextWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Booking window', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Customers only see and book times inside this window. By default that is the next available hour, for one week.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text('Bookings open', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('booking-lead-next-hour'),
              label: const Text('Next available hour'),
              selected: _leadIs(0, AdvanceUnit.hour),
              onSelected: (_) => _setLead(0, AdvanceUnit.hour),
            ),
            ChoiceChip(
              key: const Key('booking-lead-tomorrow'),
              label: const Text('Tomorrow'),
              selected: _leadIs(1, AdvanceUnit.day),
              onSelected: (_) => _setLead(1, AdvanceUnit.day),
            ),
            ChoiceChip(
              key: const Key('booking-lead-next-week'),
              label: const Text('Next week'),
              selected: _advanceUnit == AdvanceUnit.nextWeek,
              onSelected: (_) => _setLead(1, AdvanceUnit.nextWeek),
            ),
            ChoiceChip(
              key: const Key('booking-lead-custom'),
              label: const Text('Custom'),
              selected: customLead,
              onSelected: (_) => _setLead(2, AdvanceUnit.day),
            ),
          ],
        ),
        if (customLead) ...[
          const SizedBox(height: 8),
          _amountUnitRow(
            amountKey: 'booking-advance-amount',
            controller: _advanceAmount,
            unit: _advanceUnit == AdvanceUnit.nextWeek
                ? AdvanceUnit.day
                : _advanceUnit,
            includeHours: true,
            onUnit: (unit) => setState(() => _advanceUnit = unit),
            keyPrefix: 'booking-advance',
          ),
        ],
        const SizedBox(height: 16),
        Text('Customers can book for', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        _amountUnitRow(
          amountKey: 'booking-span-amount',
          controller: _openForAmount,
          unit: _openForUnit,
          includeHours: false,
          onUnit: (unit) => setState(() => _openForUnit = unit),
          keyPrefix: 'booking-span',
        ),
      ],
    );
  }

  Widget _amountUnitRow({
    required String amountKey,
    required TextEditingController controller,
    required AdvanceUnit unit,
    required bool includeHours,
    required ValueChanged<AdvanceUnit> onUnit,
    required String keyPrefix,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: TextField(
            key: Key(amountKey),
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ),
        if (includeHours)
          ChoiceChip(
            key: Key('$keyPrefix-hour'),
            label: const Text('Hours'),
            selected: unit == AdvanceUnit.hour,
            onSelected: (_) => onUnit(AdvanceUnit.hour),
          ),
        ChoiceChip(
          key: Key('$keyPrefix-day'),
          label: const Text('Days'),
          selected: unit == AdvanceUnit.day,
          onSelected: (_) => onUnit(AdvanceUnit.day),
        ),
        ChoiceChip(
          key: Key('$keyPrefix-week'),
          label: const Text('Weeks'),
          selected: unit == AdvanceUnit.week,
          onSelected: (_) => onUnit(AdvanceUnit.week),
        ),
        ChoiceChip(
          key: Key('$keyPrefix-month'),
          label: const Text('Months'),
          selected: unit == AdvanceUnit.month,
          onSelected: (_) => onUnit(AdvanceUnit.month),
        ),
      ],
    );
  }

  static const _openGreen = Color(0xFF1F6B4A);

  WidgetStateProperty<Color?> get _openChipColor {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _openGreen;
      }
      return Colors.white;
    });
  }

  TextStyle _chipLabel(bool selected) {
    return TextStyle(
      color: selected ? Colors.white : const Color(0xFF1C2B24),
      fontWeight: FontWeight.w600,
    );
  }

  void _selectMode(_OpenMode mode) {
    setState(() {
      if (mode == _OpenMode.weekdays && !_weekdays.any(weekdays.contains)) {
        _weekdays.addAll(weekdays);
      } else if (mode == _OpenMode.weekends &&
          !_weekdays.any(weekendDays.contains)) {
        _weekdays.addAll(weekendDays);
      }
      _mode = mode;
    });
  }

  void _toggleDay(int day, bool selected) {
    setState(() {
      if (selected) {
        _weekdays.add(day);
      } else {
        _weekdays.remove(day);
      }
    });
  }

  void _useSavedSchedule(List<int> savedDays) {
    _weekdays
      ..clear()
      ..addAll(savedDays);
    final opensWeekday = savedDays.any(weekdays.contains);
    final opensWeekend = savedDays.any(weekendDays.contains);
    if (opensWeekend && !opensWeekday) {
      _mode = _OpenMode.weekends;
    } else if (opensWeekday) {
      _mode = _OpenMode.weekdays;
    }
  }

  Future<void> _loadExisting() async {
    final providerId = ref.read(sessionProvider)?.providerId;
    ServiceOffering? offering;
    List<Treatment> treatments = const [];
    var alreadyOffers = false;
    if (providerId != null) {
      final provider = await ref
          .read(catalogRepositoryProvider)
          .findProvider(providerId);
      alreadyOffers = provider?.serviceIds.contains(widget.serviceId) ?? false;
      offering = await ref
          .read(offeringRepositoryProvider)
          .find(providerId: providerId, serviceId: widget.serviceId);
      treatments = await ref
          .read(offeringRepositoryProvider)
          .treatmentsFor(providerId: providerId, serviceId: widget.serviceId);
      if (offering == null && alreadyOffers && provider != null) {
        _name.text = provider.displayName;
        _description.text = provider.bio;
        final defaults = openingHoursFor(widget.serviceId);
        _weekdayHours.addAll(defaults);
        _weekendHours.addAll(defaults);
        _weekdays.addAll(everyDay);
        _mode = _OpenMode.weekdays;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = alreadyOffers;
      if (offering != null) {
        _name.text = offering.name;
        _description.text = offering.description;
        final legacy =
            offering.weekdayHours.isEmpty && offering.weekendHours.isEmpty;
        _weekdayHours
          ..clear()
          ..addAll(legacy ? offering.openHours : offering.weekdayHours);
        _weekendHours
          ..clear()
          ..addAll(legacy ? offering.openHours : offering.weekendHours);
        _useSavedSchedule(
          offering.openWeekdays.isEmpty ? everyDay : offering.openWeekdays,
        );
        _advanceAmount.text = '${offering.advanceAmount}';
        _advanceUnit = offering.advanceUnit;
        _openForAmount.text = '${offering.openForAmount}';
        _openForUnit =
            offering.openForUnit == AdvanceUnit.day ||
                offering.openForUnit == AdvanceUnit.month
            ? offering.openForUnit
            : AdvanceUnit.week;
        _autoConfirm = offering.autoConfirm;
        _concurrentBookings.text = '${offering.concurrentBookings}';
      }
      for (final draft in _treatments) {
        draft.dispose();
      }
      _treatments
        ..clear()
        ..addAll([
          for (final treatment in treatments)
            _TreatmentDraft(
              id: treatment.id,
              name: treatment.name,
              description: treatment.description,
              price: formatPrice(treatment.priceCents),
              hours: treatment.duration.inMinutes ~/ 60,
            ),
        ]);
      _loading = false;
    });
  }

  Future<void> _save(CommunityService service) async {
    final providerId = ref.read(sessionProvider)?.providerId;
    if (providerId == null || _saving) {
      return;
    }
    final appointment = service.fulfillment == FulfillmentKind.appointment;
    final beauty = service.id == beautyServiceId;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give your service a name.');
      return;
    }
    if (_mode == null) {
      setState(() => _error = 'Choose weekdays or weekends.');
      return;
    }
    if (_mode == _OpenMode.weekdays && !_weekdays.any(weekdays.contains)) {
      setState(() => _error = 'Choose at least one weekday.');
      return;
    }
    if (_mode == _OpenMode.weekends && !_weekdays.any(weekendDays.contains)) {
      setState(() => _error = 'Choose at least one weekend day.');
      return;
    }
    if (_weekdays.isEmpty) {
      setState(() => _error = 'Choose at least one open day.');
      return;
    }
    final opensWeekday = _weekdays.any(weekdays.contains);
    final opensWeekend = _weekdays.any(weekendDays.contains);
    if (opensWeekday && _weekdayHours.isEmpty) {
      setState(() => _error = 'Choose at least one weekday time.');
      return;
    }
    if (opensWeekend && _weekendHours.isEmpty) {
      setState(() => _error = 'Choose at least one weekend time.');
      return;
    }
    final advanceAmount = int.tryParse(_advanceAmount.text.trim());
    final openForAmount = int.tryParse(_openForAmount.text.trim());
    if (advanceAmount == null || advanceAmount < 0) {
      setState(() => _error = 'Enter how far ahead bookings open.');
      return;
    }
    if (openForAmount == null || openForAmount < 1) {
      setState(() => _error = 'Enter how long customers can book for.');
      return;
    }
    final concurrentBookings = int.tryParse(_concurrentBookings.text.trim());
    if (appointment && (concurrentBookings == null || concurrentBookings < 1)) {
      setState(
        () => _error = 'Enter how many customers can book the same time.',
      );
      return;
    }
    if (beauty) {
      for (final treatment in _treatments) {
        if (treatment.name.text.trim().isEmpty) {
          setState(() => _error = 'Give each treatment a name.');
          return;
        }
      }
    }
    int? priceCents;
    if (!appointment) {
      priceCents = parsePriceToCents(_price.text);
    }
    final drafts = [
      for (final treatment in _treatments)
        TreatmentDraft(
          id: treatment.id,
          name: treatment.name.text,
          description: treatment.description.text,
          durationHours: treatment.hours,
          priceCents: parsePriceToCents(treatment.price.text),
        ),
    ];

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = _editing
        ? await ref
              .read(updateOfferingProvider)
              .call(
                providerId: providerId,
                serviceId: service.id,
                offeringName: _name.text,
                offeringDescription: _description.text,
                weekdayHours: opensWeekday ? _weekdayHours.toList() : const [],
                weekendHours: opensWeekend ? _weekendHours.toList() : const [],
                openWeekdays: _weekdays.toList(),
                advanceAmount: advanceAmount,
                advanceUnit: _advanceUnit,
                openForAmount: openForAmount,
                openForUnit: _openForUnit,
                autoConfirm: _autoConfirm,
                concurrentBookings: concurrentBookings ?? 1,
                treatments: drafts,
              )
        : await ref
              .read(offerServiceProvider)
              .call(
                providerId: providerId,
                serviceId: service.id,
                itemName: _itemName.text,
                priceCents: priceCents,
                offeringName: _name.text,
                offeringDescription: _description.text,
                weekdayHours: opensWeekday ? _weekdayHours.toList() : const [],
                weekendHours: opensWeekend ? _weekendHours.toList() : const [],
                openWeekdays: _weekdays.toList(),
                advanceAmount: advanceAmount,
                advanceUnit: _advanceUnit,
                openForAmount: openForAmount,
                openForUnit: _openForUnit,
                autoConfirm: _autoConfirm,
                concurrentBookings: concurrentBookings ?? 1,
                treatments: drafts,
              );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        invalidateOfferViews(ref);
        context.go('/provider');
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = offerFailureMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit your service' : 'Set up your service'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AsyncView(
              value: services,
              data: (items) {
                CommunityService? service;
                for (final candidate in items) {
                  if (candidate.id == widget.serviceId) {
                    service = candidate;
                  }
                }
                if (service == null) {
                  return const Center(
                    child: Text('That category is not listed.'),
                  );
                }
                final category = service;
                if (!_seeded) {
                  _seeded = true;
                  if (category.id == beautyServiceId && _treatments.isEmpty) {
                    _treatments.add(_TreatmentDraft(expanded: true));
                  }
                }
                final appointment =
                    category.fulfillment == FulfillmentKind.appointment;
                final beauty = category.id == beautyServiceId;
                return ListView(
                  key: const Key('configure-offering-list'),
                  padding: pagePadding,
                  children: [
                    Text(category.name, style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Customers will see this name when they open ${category.name}.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('offering-name-field'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Service name',
                        hintText: 'Maegan beauty parlor',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('offering-description-field'),
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Open days', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Choose Weekdays or Weekends. Each keeps its own times, and you can turn individual days off.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: const Key('open-days-weekdays'),
                          label: const Text('Weekdays'),
                          selected: _mode == _OpenMode.weekdays,
                          color: _openChipColor,
                          labelStyle: _chipLabel(_mode == _OpenMode.weekdays),
                          onSelected: (selected) {
                            if (selected) {
                              _selectMode(_OpenMode.weekdays);
                            }
                          },
                        ),
                        ChoiceChip(
                          key: const Key('open-days-weekends'),
                          label: const Text('Weekends'),
                          selected: _mode == _OpenMode.weekends,
                          color: _openChipColor,
                          labelStyle: _chipLabel(_mode == _OpenMode.weekends),
                          onSelected: (selected) {
                            if (selected) {
                              _selectMode(_OpenMode.weekends);
                            }
                          },
                        ),
                      ],
                    ),
                    if (_mode == _OpenMode.weekdays ||
                        _mode == _OpenMode.weekends) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (day, label) in openDayChoices)
                            if (_mode == _OpenMode.weekdays
                                ? weekdays.contains(day)
                                : weekendDays.contains(day))
                              ChoiceChip(
                                key: ValueKey('open-day-$day'),
                                label: Text(label),
                                selected: _weekdays.contains(day),
                                color: _openChipColor,
                                labelStyle: _chipLabel(_weekdays.contains(day)),
                                onSelected: (selected) =>
                                    _toggleDay(day, selected),
                              ),
                        ],
                      ),
                    ],
                    if (_mode == _OpenMode.weekdays)
                      _hourChoices(
                        title: 'Weekday times',
                        subtitle:
                            'Monday to Friday, any hour from 00:00 to 23:00.',
                        keyPrefix: 'weekday-hour',
                        selected: _weekdayHours,
                      ),
                    if (_mode == _OpenMode.weekends)
                      _hourChoices(
                        title: 'Weekend times',
                        subtitle:
                            'Saturday and Sunday, any hour from 00:00 to 23:00.',
                        keyPrefix: 'weekend-hour',
                        selected: _weekendHours,
                      ),
                    _bookingWindowSection(),
                    if (appointment) ...[
                      TextField(
                        key: const Key('concurrent-bookings'),
                        controller: _concurrentBookings,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Concurrent bookings',
                          helperText:
                              'How many customers can book the same time.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const Key('auto-confirm-bookings'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto confirm'),
                        subtitle: Text(
                          _autoConfirm
                              ? 'New bookings are confirmed as soon as a customer reserves a time.'
                              : 'New bookings stay pending until you confirm them.',
                        ),
                        value: _autoConfirm,
                        onChanged: (value) {
                          setState(() => _autoConfirm = value);
                        },
                      ),
                    ],
                    if (category.id == carWashServiceId && _editing) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('edit-washes'),
                          onPressed: () =>
                              context.push('/provider/washes/${category.id}'),
                          child: const Text('Edit washes'),
                        ),
                      ),
                    ],
                    if (beauty) ...[
                      const SizedBox(height: 20),
                      Text('Treatments', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Add each treatment with a price, a duration, and a description.',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < _treatments.length;
                        index++
                      ) ...[
                        _TreatmentCard(
                          index: index,
                          draft: _treatments[index],
                          onChanged: () => setState(() {}),
                          onRemove: _treatments.length == 1
                              ? null
                              : () {
                                  setState(() {
                                    _treatments.removeAt(index).dispose();
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('add-treatment'),
                          onPressed: () {
                            setState(() {
                              _treatments.add(_TreatmentDraft(expanded: true));
                            });
                          },
                          child: const Text('Add a treatment'),
                        ),
                      ),
                    ],
                    if (!appointment) ...[
                      const SizedBox(height: 20),
                      TextField(
                        key: const Key('item-name-field'),
                        controller: _itemName,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Meal name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('item-price-field'),
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '85.00',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The meal stays on the menu for seven days.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('offer-error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('save-offering'),
                      onPressed: _saving ? null : () => _save(category),
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : (_editing
                                  ? 'Save service'
                                  : 'Offer this service'),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

enum _OpenMode { weekdays, weekends }

class _TreatmentDraft {
  _TreatmentDraft({
    this.id,
    this.expanded = false,
    String name = '',
    String description = '',
    String price = '',
    this.hours,
  }) {
    this.name.text = name;
    this.description.text = description;
    this.price.text = price;
  }

  final String? id;
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  int? hours;
  final bool expanded;

  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _TreatmentDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final title = draft.name.text.trim().isEmpty
        ? 'New treatment'
        : draft.name.text.trim();
    return Card(
      child: ExpansionTile(
        key: ValueKey('expand-treatment-$index'),
        initiallyExpanded: draft.expanded,
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: ValueKey('treatment-name-$index'),
                  controller: draft.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Treatment'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey('treatment-description-$index'),
                  controller: draft.description,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Text('Duration', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hours in washDurationHours)
                      ChoiceChip(
                        key: ValueKey('treatment-hours-$index-$hours'),
                        label: Text(hours == 1 ? '1 hour' : '$hours hours'),
                        selected: draft.hours == hours,
                        onSelected: (selected) {
                          draft.hours = selected ? hours : null;
                          onChanged();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey('treatment-price-$index'),
                  controller: draft.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price (R)',
                    hintText: '200.00',
                  ),
                ),
                if (onRemove != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: ValueKey('remove-treatment-$index'),
                      onPressed: onRemove,
                      child: const Text('Remove treatment'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
