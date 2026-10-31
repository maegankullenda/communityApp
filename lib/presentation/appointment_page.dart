import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/profile/domain/car_wash_pricing.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/slot_coverage.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';
import 'package:community_app/features/scheduling/domain/wash_quote.dart';
import 'package:community_app/presentation/day_tabs.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class AppointmentPage extends ConsumerStatefulWidget {
  const AppointmentPage({
    required this.service,
    required this.provider,
    this.appointmentId,
    super.key,
  });

  final CommunityService service;
  final ServiceProvider provider;
  final String? appointmentId;

  @override
  ConsumerState<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends ConsumerState<AppointmentPage> {
  int? _selectedHour;
  int? _selectedMinute;
  String? _resolvedSlotId;
  Appointment? _appointmentToUpdate;
  final Map<String, String> _washByVehicle = {};
  final Set<String> _selectedVehicleIds = {};
  DateTime? _selectedDay;
  String? _treatmentId;
  String? _error;
  bool _booking = false;
  bool _hydrated = false;
  bool _vehiclesHydrated = false;
  DateTime? _appliedDay;

  Future<void> _book() async {
    final slotId = _resolvedSlotId;
    final userId = ref.read(sessionProvider)?.id;
    final needsVehicle = serviceRequiresVehicle(widget.service.id);
    final existing = _existingAppointment(watch: false);
    final editing =
        existing != null &&
        existing.canCustomerChange &&
        existing.userId == userId;
    if (slotId == null || userId == null || _booking) {
      return;
    }
    if (needsVehicle && _selectedVehicleIds.isEmpty) {
      setState(() {
        _error = bookingFailureMessage(BookingFailure.vehicleRequired);
      });
      return;
    }
    final offered = await ref
        .read(washRepositoryProvider)
        .washesFor(
          providerId: widget.provider.id,
          serviceId: widget.service.id,
        );
    final chosenWashes = {
      for (final id in _selectedVehicleIds)
        if ((_washByVehicle[id] ?? '').isNotEmpty) id: _washByVehicle[id]!,
    };
    if (offered.isNotEmpty &&
        chosenWashes.length != _selectedVehicleIds.length) {
      setState(() {
        _error = bookingFailureMessage(BookingFailure.washRequired);
      });
      return;
    }
    final treatments = await ref
        .read(offeringRepositoryProvider)
        .treatmentsFor(
          providerId: widget.provider.id,
          serviceId: widget.service.id,
        );
    final treatmentId = treatments.any((item) => item.id == _treatmentId)
        ? _treatmentId
        : null;
    if (treatments.isNotEmpty && treatmentId == null) {
      setState(() {
        _error = bookingFailureMessage(BookingFailure.treatmentRequired);
      });
      return;
    }
    final matchesEditedTreatment =
        treatments.isEmpty || existing?.washId == treatmentId;
    final bookingToChange =
        _appointmentToUpdate ??
        (editing && matchesEditedTreatment ? existing : null);
    setState(() {
      _booking = true;
      _error = null;
    });
    final result = bookingToChange != null
        ? await ref
              .read(changeAppointmentProvider)
              .call(
                userId: userId,
                appointmentId: bookingToChange.id,
                slotId: slotId,
                serviceId: widget.service.id,
                vehicleIds: needsVehicle
                    ? _selectedVehicleIds.toList()
                    : const [],
                vehicleWashes: chosenWashes,
                treatmentId: treatmentId,
              )
        : await ref
              .read(bookAppointmentProvider)
              .call(
                userId: userId,
                slotId: slotId,
                serviceId: widget.service.id,
                vehicleIds: needsVehicle
                    ? _selectedVehicleIds.toList()
                    : const [],
                vehicleWashes: chosenWashes,
                treatmentId: treatmentId,
              );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        setState(() => _booking = false);
        invalidateBookingViews(ref);
        context.go('/activity');
      case Err(:final error):
        setState(() {
          _booking = false;
          _error = bookingFailureMessage(error);
          if (error == BookingFailure.slotFull ||
              error == BookingFailure.alreadyBooked) {
            if (bookingToChange != null) {
              _selectedHour = bookingToChange.start.hour;
              _selectedMinute = bookingToChange.start.minute;
              _selectedDay = DateTime(
                bookingToChange.start.year,
                bookingToChange.start.month,
                bookingToChange.start.day,
              );
            } else {
              _selectedHour = null;
              _selectedMinute = null;
            }
          }
        });
        invalidateBookingViews(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    final offeringQuery = OfferingQuery(
      providerId: widget.provider.id,
      serviceId: widget.service.id,
    );
    final offeringState = ref.watch(offeringProvider(offeringQuery));
    final offering = offeringState.asData?.value;
    final scheduleReady = offeringState.hasValue || offeringState.hasError;
    final window = offering?.bookingWindow ?? const BookingWindow();
    final range = bookingRange(now, window);
    final from = DateTime(
      range.earliest.year,
      range.earliest.month,
      range.earliest.day,
    );
    final query = SlotQuery(
      serviceId: widget.service.id,
      providerId: widget.provider.id,
      from: from,
      to: range.until,
    );
    final slots = ref.watch(slotsProvider(query));
    final profile = ref.watch(profileProvider);
    final treatments =
        ref.watch(treatmentsProvider(offeringQuery)).asData?.value ??
        const <Treatment>[];
    final washes = ref
        .watch(
          washesProvider(
            WashQuery(
              providerId: widget.provider.id,
              serviceId: widget.service.id,
            ),
          ),
        )
        .asData
        ?.value;
    final existing = _prepareExisting(
      profileReady: profile.hasValue && !profile.isLoading,
      vehicles: profile.asData?.value.vehicles ?? const [],
    );
    final editing =
        existing != null &&
        existing.canCustomerChange &&
        existing.userId == ref.watch(sessionProvider)?.id;
    final providerBookings = bookingsForProvider(
      activity: ref.watch(myActivityProvider).asData?.value,
      userId: ref.watch(sessionProvider)?.id,
      serviceId: widget.service.id,
      providerId: widget.provider.id,
    );
    final needsVehicle = serviceRequiresVehicle(widget.service.id);
    final vehicles = profile.asData?.value.vehicles ?? const <Vehicle>[];
    final textTheme = Theme.of(context).textTheme;

    Treatment? selectedTreatment;
    for (final treatment in treatments) {
      if (treatment.id == _treatmentId) {
        selectedTreatment = treatment;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(offering?.name ?? widget.provider.displayName),
      ),
      body: AsyncView(
        value: slots,
        data: (items) {
          bool listed(TimeSlot slot) {
            if (!scheduleReady) {
              return false;
            }
            if (!isWithinBookingWindow(slot.start, now, window)) {
              return false;
            }
            final schedule = offering;
            return schedule == null || schedule.isOpenAt(slot.start);
          }

          final grouped = groupSlotsByDay([
            for (final slot in items)
              if (listed(slot)) slot,
          ]);
          final days = grouped.keys.toList()..sort();
          final selectedDay =
              _selectedDay != null && grouped.containsKey(_selectedDay)
              ? _selectedDay!
              : (days.isEmpty ? null : days.first);
          final daySlots = selectedDay == null
              ? const <TimeSlot>[]
              : grouped[selectedDay]!;
          final dayBookings = [
            for (final booking in providerBookings)
              if (selectedDay != null &&
                  booking.start.year == selectedDay.year &&
                  booking.start.month == selectedDay.month &&
                  booking.start.day == selectedDay.day)
                booking,
          ];
          _applyBookedDay(
            day: selectedDay,
            activityReady:
                ref.watch(myActivityProvider).hasValue &&
                !ref.watch(myActivityProvider).isLoading,
            profileReady: profile.hasValue && !profile.isLoading,
            editing: editing ? existing : null,
            dayBookings: dayBookings,
            vehicles: vehicles,
            needsVehicle: needsVehicle,
          );
          final offered = washes ?? const <WashOption>[];
          final vehicleTypes = {
            for (final vehicle in vehicles) vehicle.id: vehicle.type,
          };
          final quote = quoteVehicleWashes(
            offered: offered,
            vehicleIds: _selectedVehicleIds.toList(),
            vehicleTypes: vehicleTypes,
            vehicleWashes: _washByVehicle,
          );
          final washTotal =
              selectedTreatment?.priceCents ??
              switch (quote) {
                Success(value: final chosen?) => chosen.priceCents,
                _ => null,
              };
          final washDuration =
              selectedTreatment?.duration ??
              switch (quote) {
                Success(value: final chosen?) => chosen.duration,
                _ => _assignedWashDuration(offered, vehicleTypes),
              };
          bool slotOpen(TimeSlot slot) {
            if (!listed(slot)) {
              return false;
            }
            final own = [
              for (final booking in providerBookings)
                if (booking.slotId == slot.id &&
                    (_treatmentId == null || booking.washId == _treatmentId))
                  booking,
              if (editing && existing.isActive && existing.slotId == slot.id)
                existing,
            ];
            final held = {
              for (final booking in own)
                for (final covered in slotsCoveredBy(
                  slots: items,
                  providerId: booking.providerId,
                  serviceId: booking.serviceId,
                  start: booking.start,
                  duration: booking.duration,
                ))
                  covered.id,
            };
            return washFitsOn(
              start: slot,
              duration: washDuration ?? slot.duration,
              slots: items,
              heldSlotIds: held,
            );
          }

          final chosen = openSlotAtClock(
            daySlots,
            hour: _selectedHour,
            minute: _selectedMinute,
            available: slotOpen,
          );
          _resolvedSlotId = chosen?.id;
          _appointmentToUpdate = bookingToUpdate(
            dayBookings: dayBookings,
            vehicles: vehicles,
            selectedIds: _selectedVehicleIds,
            chosenSlotId: chosen?.id,
            selectedWashId: treatments.isEmpty ? null : _treatmentId,
          );
          final updating =
              _appointmentToUpdate != null ||
              (editing &&
                  (treatments.isEmpty || existing.washId == _treatmentId));
          final selectedVehicles = [
            for (final vehicle in vehicles)
              if (_selectedVehicleIds.contains(vehicle.id)) vehicle,
          ];
          final selectedTotal = selectedVehicles.fold<int>(
            0,
            (sum, vehicle) => sum + carWashPriceCents(vehicle.type),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (days.isNotEmpty) ...[
                const SizedBox(height: 8),
                DayTabs(
                  days: days,
                  selected: selectedDay,
                  onSelected: (day) => setState(() => _selectedDay = day),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.service.name, style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      (offering?.description.isNotEmpty ?? false)
                          ? offering!.description
                          : widget.provider.bio,
                      style: textTheme.bodySmall,
                    ),
                    if (offering != null &&
                        selectedDay != null &&
                        offering.hoursOn(selectedDay.weekday).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Open ${formatOpeningHours(offering.hoursOn(selectedDay.weekday))}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (days.isEmpty)
                const Expanded(
                  child: Center(child: Text('No times are open yet.')),
                )
              else ...[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (treatments.isNotEmpty) ...[
                        Text('Treatment', style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final treatment in treatments)
                          ListTile(
                            key: ValueKey('book-treatment-${treatment.name}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _treatmentId == treatment.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            title: Text(treatment.name),
                            subtitle: Text(
                              '${treatment.durationLabel} · ${formatRand(treatment.priceCents)}',
                            ),
                            trailing: IconButton(
                              key: ValueKey(
                                'treatment-details-${treatment.name}',
                              ),
                              tooltip: 'What this treatment includes',
                              onPressed: () =>
                                  showTreatmentDetails(context, treatment),
                              icon: const Icon(Icons.info_outline),
                            ),
                            onTap: () {
                              setState(() {
                                _error = null;
                                if (_treatmentId == treatment.id) {
                                  return;
                                }
                                _treatmentId = treatment.id;
                                final next = selectionForTreatment(
                                  treatmentId: treatment.id,
                                  dayBookings: dayBookings,
                                );
                                _selectedHour = next.hour;
                                _selectedMinute = next.minute;
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (needsVehicle) ...[
                        Text('Vehicles', style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          offered.isEmpty
                              ? 'Select every vehicle to wash at this time.'
                              : 'Select every vehicle, then choose its wash. The same wash is charged for each vehicle.',
                          style: textTheme.bodySmall,
                        ),
                        if (offered.isEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Hatch ${formatPrice(carWashPriceCents(VehicleType.hatch))} · Sedan ${formatPrice(carWashPriceCents(VehicleType.sedan))} · SUV ${formatPrice(carWashPriceCents(VehicleType.suv))}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (vehicles.isEmpty)
                          TextButton(
                            key: const Key('go-to-profile'),
                            onPressed: () => context.go('/profile'),
                            child: const Text(
                              'Add a vehicle on your profile before booking a wash.',
                            ),
                          )
                        else
                          for (final vehicle in vehicles) ...[
                            ListTile(
                              key: ValueKey('book-vehicle-${vehicle.name}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(vehicle.name),
                              subtitle: _bookedForLabel(
                                vehicle,
                                dayBookings,
                                vehicles,
                              ),
                              selected: _selectedVehicleIds.contains(
                                vehicle.id,
                              ),
                              trailing: _selectedVehicleIds.contains(vehicle.id)
                                  ? Icon(
                                      Icons.check,
                                      key: ValueKey(
                                        'book-vehicle-selected-${vehicle.name}',
                                      ),
                                      color: const Color(0xFF1F6B4A),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _error = null;
                                  if (_selectedVehicleIds.contains(
                                    vehicle.id,
                                  )) {
                                    _selectedVehicleIds.remove(vehicle.id);
                                    _washByVehicle.remove(vehicle.id);
                                  } else {
                                    _selectedVehicleIds.add(vehicle.id);
                                  }
                                });
                              },
                            ),
                            if (offered.isNotEmpty &&
                                _selectedVehicleIds.contains(vehicle.id))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final wash in offered)
                                      ChoiceChip(
                                        key: ValueKey(
                                          _washByVehicle[vehicle.id] == wash.id
                                              ? 'book-wash-selected-${vehicle.name}-${wash.name}'
                                              : 'book-wash-${vehicle.name}-${wash.name}',
                                        ),
                                        label: Text(
                                          '${wash.name} · ${formatRand(wash.rateFor(vehicle.type).priceCents)}',
                                        ),
                                        selected:
                                            _washByVehicle[vehicle.id] ==
                                            wash.id,
                                        onSelected: (selected) {
                                          setState(() {
                                            _error = null;
                                            if (selected) {
                                              _washByVehicle[vehicle.id] =
                                                  wash.id;
                                            } else {
                                              _washByVehicle.remove(vehicle.id);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        const SizedBox(height: 16),
                      ],
                      if (offered.isNotEmpty) ...[
                        Text('Wash', style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final wash in offered)
                          ListTile(
                            key: ValueKey('wash-price-${wash.name}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(wash.name),
                            subtitle: Text(washDurationSummary(wash)),
                            trailing: IconButton(
                              key: ValueKey('wash-details-${wash.name}'),
                              tooltip: 'What this wash includes',
                              onPressed: () => showWashDetails(context, wash),
                              icon: const Icon(Icons.info_outline),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final slot in daySlots)
                            ChoiceChip(
                              key: ValueKey('slot-${slot.id}'),
                              label: Text(
                                slotChoiceLabel(
                                  time: formatTime(slot.start),
                                  open: slotOpen(slot),
                                  heldByCustomer: customerHoldsSlot(
                                    slot: slot,
                                    bookings: providerBookings,
                                    slots: items,
                                  ),
                                ),
                              ),
                              selected: chosen?.id == slot.id,
                              onSelected: slotOpen(slot)
                                  ? (selected) {
                                      setState(() {
                                        _selectedHour = selected
                                            ? slot.start.hour
                                            : null;
                                        _selectedMinute = selected
                                            ? slot.start.minute
                                            : null;
                                      });
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    key: const Key('booking-error'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: pagePadding,
                child: FilledButton(
                  key: const Key('book-slot'),
                  onPressed: chosen == null || _booking ? null : _book,
                  child: Text(
                    _booking
                        ? (updating ? 'Updating…' : 'Booking…')
                        : _bookLabel(
                            updating: updating,
                            washTotal: washTotal,
                            vehicleTotal: selectedVehicles.isEmpty
                                ? null
                                : selectedTotal,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Appointment? _existingAppointment({bool watch = true}) {
    final appointmentId = widget.appointmentId;
    if (appointmentId == null) {
      return null;
    }
    final value = watch
        ? ref.watch(appointmentByIdProvider(appointmentId))
        : ref.read(appointmentByIdProvider(appointmentId));
    return value.asData?.value;
  }

  Appointment? _prepareExisting({
    required bool profileReady,
    required List<Vehicle> vehicles,
  }) {
    final existing = _existingAppointment();
    final userId = ref.watch(sessionProvider)?.id;
    if (existing == null ||
        !existing.canCustomerChange ||
        existing.userId != userId) {
      return existing;
    }
    if (!_hydrated) {
      _hydrated = true;
      _selectedHour = existing.start.hour;
      _selectedMinute = existing.start.minute;
      _washByVehicle
        ..clear()
        ..addAll(existing.washesForVehicles());
      if (!serviceRequiresVehicle(widget.service.id)) {
        _treatmentId = existing.washId;
      }
      _selectedDay = DateTime(
        existing.start.year,
        existing.start.month,
        existing.start.day,
      );
    }
    if (profileReady && !_vehiclesHydrated) {
      _vehiclesHydrated = true;
      _selectedVehicleIds.addAll(_savedVehicleIds(existing, vehicles));
    }
    return existing;
  }

  /// Shows the booking already made for [day], the same way editing does.
  void _applyBookedDay({
    required DateTime? day,
    required bool activityReady,
    required bool profileReady,
    required Appointment? editing,
    required List<Appointment> dayBookings,
    required List<Vehicle> vehicles,
    required bool needsVehicle,
  }) {
    if (day == null || _appliedDay == day) {
      return;
    }
    final editingThisDay = editing != null && _isSameDay(editing.start, day);
    if (editingThisDay) {
      if (needsVehicle && !profileReady) {
        return;
      }
      _appliedDay = day;
      _selectedHour = editing.start.hour;
      _selectedMinute = editing.start.minute;
      _washByVehicle
        ..clear()
        ..addAll(editing.washesForVehicles());
      if (!needsVehicle) {
        _treatmentId = editing.washId;
      }
      if (needsVehicle) {
        _selectedVehicleIds
          ..clear()
          ..addAll(vehicleIdsOnBooking(editing, vehicles));
      }
      return;
    }
    if (!activityReady || (needsVehicle && !profileReady)) {
      return;
    }
    _appliedDay = day;
    final shown = bookingsToShow(dayBookings);
    if (shown.isEmpty) {
      return;
    }
    final primary = shown.first;
    _selectedHour = primary.start.hour;
    _selectedMinute = primary.start.minute;
    _washByVehicle
      ..clear()
      ..addAll({for (final booking in shown) ...booking.washesForVehicles()});
    if (!needsVehicle) {
      _treatmentId = primary.washId;
    }
    if (needsVehicle) {
      _selectedVehicleIds
        ..clear()
        ..addAll([
          for (final booking in shown)
            ...vehicleIdsOnBooking(booking, vehicles),
        ]);
    }
  }

  Duration? _assignedWashDuration(
    List<WashOption> offered,
    Map<String, VehicleType> vehicleTypes,
  ) {
    Duration? longest;
    for (final vehicleId in _selectedVehicleIds) {
      final washId = _washByVehicle[vehicleId];
      if (washId == null) {
        continue;
      }
      for (final wash in offered) {
        if (wash.id != washId) {
          continue;
        }
        final rate = wash.rateFor(vehicleTypes[vehicleId] ?? VehicleType.hatch);
        if (longest == null || rate.duration > longest) {
          longest = rate.duration;
        }
      }
    }
    return longest;
  }

  Iterable<String> _savedVehicleIds(
    Appointment existing,
    List<Vehicle> vehicles,
  ) {
    return vehicleIdsOnBooking(existing, vehicles);
  }

  Widget? _bookedForLabel(
    Vehicle vehicle,
    List<Appointment> dayBookings,
    List<Vehicle> vehicles,
  ) {
    final booking = bookingForVehicle(
      vehicle: vehicle,
      vehicles: vehicles,
      dayBookings: dayBookings,
    );
    if (booking == null) {
      return null;
    }
    return Text('Book for ${formatTime(booking.start)}');
  }
}

/// One duration when every vehicle type matches, otherwise the shortest to longest.
String washDurationSummary(WashOption wash) {
  var shortest = wash.rateFor(VehicleType.hatch).durationHours;
  var longest = shortest;
  for (final type in VehicleType.values) {
    final hours = wash.rateFor(type).durationHours;
    if (hours < shortest) {
      shortest = hours;
    }
    if (hours > longest) {
      longest = hours;
    }
  }
  if (shortest == longest) {
    return 'Duration: ~${shortest}h';
  }
  return 'Duration: $shortest-$longest hours';
}

Future<void> showTreatmentDetails(BuildContext context, Treatment treatment) {
  final description = treatment.description.trim();
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(treatment.name),
        content: Text(
          description.isEmpty
              ? 'No description for this treatment yet.'
              : description,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> showWashDetails(BuildContext context, WashOption wash) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(wash.name),
        content: Text(
          wash.description.isEmpty
              ? 'No description for this wash yet.'
              : wash.description,
        ),
        actions: [
          TextButton(
            key: const Key('close-wash-details'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

String _bookLabel({
  required bool updating,
  required int? washTotal,
  required int? vehicleTotal,
}) {
  final action = updating ? 'Update booking' : 'Book this time';
  if (washTotal != null) {
    return '$action · ${formatRand(washTotal)}';
  }
  if (vehicleTotal == null) {
    return action;
  }
  return '$action · ${formatPrice(vehicleTotal)}';
}

/// The customer's own time reads as booked. A time with no seats left reads
/// as fully booked for everyone else.
String slotChoiceLabel({
  required String time,
  required bool open,
  required bool heldByCustomer,
}) {
  if (heldByCustomer) {
    return '$time Booked';
  }
  if (!open) {
    return '$time Fully booked';
  }
  return time;
}

bool customerHoldsSlot({
  required TimeSlot slot,
  required Iterable<Appointment> bookings,
  required Iterable<TimeSlot> slots,
}) {
  for (final booking in bookings) {
    if (!booking.isActive ||
        booking.providerId != slot.providerId ||
        booking.serviceId != slot.serviceId) {
      continue;
    }
    if (booking.slotId == slot.id) {
      return true;
    }
    final covered = slotsCoveredBy(
      slots: slots,
      providerId: booking.providerId,
      serviceId: booking.serviceId,
      start: booking.start,
      duration: booking.duration,
    );
    if (covered.any((item) => item.id == slot.id)) {
      return true;
    }
  }
  return false;
}

/// The same clock time on [daySlots], when it is still open.
/// A booked time returns null so the choice is not shown as selected.
TimeSlot? openSlotAtClock(
  List<TimeSlot> daySlots, {
  required int? hour,
  required int? minute,
  required bool Function(TimeSlot slot) available,
}) {
  if (hour == null || minute == null) {
    return null;
  }
  for (final slot in daySlots) {
    if (slot.start.hour != hour || slot.start.minute != minute) {
      continue;
    }
    if (available(slot)) {
      return slot;
    }
    return null;
  }
  return null;
}

List<Appointment> bookingsForProvider({
  required MyActivity? activity,
  required String? userId,
  required String serviceId,
  required String providerId,
}) {
  if (activity == null || userId == null) {
    return const [];
  }
  return [
    for (final summary in activity.appointments)
      if (summary.appointment.isActive &&
          summary.appointment.userId == userId &&
          summary.appointment.serviceId == serviceId &&
          summary.appointment.providerId == providerId)
        summary.appointment,
  ];
}

Set<String> vehicleIdsOnBooking(Appointment booking, List<Vehicle> vehicles) {
  final known = {
    for (final id in booking.vehicleIds)
      if (vehicles.any((vehicle) => vehicle.id == id)) id,
  };
  if (known.isNotEmpty) {
    return known;
  }
  final labels = booking.vehicleLabel?.split(', ').toSet() ?? const {};
  return {
    for (final vehicle in vehicles)
      if (labels.contains(vehicleBookingLabel(vehicle))) vehicle.id,
  };
}

Appointment? bookingForVehicle({
  required Vehicle vehicle,
  required List<Vehicle> vehicles,
  required List<Appointment> dayBookings,
}) {
  for (final booking in dayBookings) {
    if (vehicleIdsOnBooking(booking, vehicles).contains(vehicle.id)) {
      return booking;
    }
  }
  return null;
}

bool _isSameDay(DateTime start, DateTime day) {
  return start.year == day.year &&
      start.month == day.month &&
      start.day == day.day;
}

/// Time to show after choosing [treatmentId].
///
/// The booked time stays selected for that treatment. Another treatment
/// starts with no time, unless that treatment is already booked once today.
({int? hour, int? minute}) selectionForTreatment({
  required String treatmentId,
  required List<Appointment> dayBookings,
}) {
  final matches = [
    for (final booking in dayBookings)
      if (booking.washId == treatmentId) booking,
  ];
  if (matches.length != 1) {
    return (hour: null, minute: null);
  }
  return (hour: matches.single.start.hour, minute: matches.single.start.minute);
}

/// Bookings that share the earliest time and wash on this day.
List<Appointment> bookingsToShow(List<Appointment> dayBookings) {
  if (dayBookings.isEmpty) {
    return const [];
  }
  final sorted = [...dayBookings]..sort((a, b) => a.start.compareTo(b.start));
  final first = sorted.first;
  return [
    for (final booking in sorted)
      if (booking.start == first.start && booking.washId == first.washId)
        booking,
  ];
}

/// The booking the current choice belongs to, including one that is unchanged.
///
/// A different treatment is a new booking. It does not move the treatment
/// already booked at another time.
Appointment? bookingToUpdate({
  required List<Appointment> dayBookings,
  required List<Vehicle> vehicles,
  required Set<String> selectedIds,
  required String? chosenSlotId,
  String? selectedWashId,
}) {
  if (chosenSlotId == null) {
    return null;
  }
  if (selectedIds.isEmpty) {
    final forTreatment = selectedWashId == null
        ? dayBookings
        : [
            for (final booking in dayBookings)
              if (booking.washId == selectedWashId) booking,
          ];
    final onSlot = [
      for (final booking in forTreatment)
        if (booking.slotId == chosenSlotId) booking,
    ];
    if (onSlot.length == 1) {
      return onSlot.first;
    }
    if (selectedWashId != null) {
      return forTreatment.length == 1 ? forTreatment.first : null;
    }
    if (onSlot.isEmpty && dayBookings.length == 1) {
      return dayBookings.first;
    }
    return null;
  }
  Appointment? match;
  for (final booking in dayBookings) {
    final ids = vehicleIdsOnBooking(booking, vehicles);
    if (!ids.any(selectedIds.contains)) {
      continue;
    }
    if (match != null) {
      return null;
    }
    match = booking;
  }
  return match;
}

Map<DateTime, List<TimeSlot>> groupSlotsByDay(List<TimeSlot> slots) {
  final grouped = <DateTime, List<TimeSlot>>{};
  for (final slot in slots) {
    final day = DateTime(slot.start.year, slot.start.month, slot.start.day);
    grouped.putIfAbsent(day, () => []).add(slot);
  }
  for (final daySlots in grouped.values) {
    final byStart = <DateTime, TimeSlot>{};
    for (final slot in daySlots) {
      final start = DateTime(
        slot.start.year,
        slot.start.month,
        slot.start.day,
        slot.start.hour,
        slot.start.minute,
      );
      final existing = byStart[start];
      if (existing == null || slot.bookedCount > existing.bookedCount) {
        byStart[start] = slot;
      }
    }
    daySlots
      ..clear()
      ..addAll(byStart.values)
      ..sort((a, b) => a.start.compareTo(b.start));
  }
  return grouped;
}
