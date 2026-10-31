import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({this.includeVehicles = true, super.key});

  final bool includeVehicles;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _address = TextEditingController();
  final _contactNumber = TextEditingController();
  final _newVehicleName = TextEditingController();
  final _newVehicleRegistration = TextEditingController();
  final Map<String, TextEditingController> _vehicleNames = {};
  final Map<String, TextEditingController> _vehicleRegistrations = {};
  VehicleType _newVehicleType = VehicleType.hatch;
  List<Vehicle> _vehicles = [];
  String? _accountId;
  bool _hydrated = false;
  bool _saving = false;
  String? _error;
  String? _savedMessage;
  Timer? _savedNotice;
  int _drafts = 0;

  @override
  void dispose() {
    _savedNotice?.cancel();
    _firstName.dispose();
    _surname.dispose();
    _address.dispose();
    _contactNumber.dispose();
    _newVehicleName.dispose();
    _newVehicleRegistration.dispose();
    for (final controller in _vehicleNames.values) {
      controller.dispose();
    }
    for (final controller in _vehicleRegistrations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _nameController(Vehicle vehicle) {
    return _vehicleNames.putIfAbsent(
      vehicle.id,
      () => TextEditingController(text: vehicle.name),
    );
  }

  TextEditingController _registrationController(Vehicle vehicle) {
    return _vehicleRegistrations.putIfAbsent(
      vehicle.id,
      () => TextEditingController(text: vehicle.registration),
    );
  }

  void _hydrate(CustomerProfile profile) {
    _firstName.text = profile.firstName;
    _surname.text = profile.surname;
    _address.text = profile.address;
    _contactNumber.text = profile.contactNumber;
    _vehicles = [...profile.vehicles];
    final liveIds = profile.vehicles.map((vehicle) => vehicle.id).toSet();
    final stale = _vehicleNames.keys.where((id) => !liveIds.contains(id));
    for (final id in stale.toList()) {
      _vehicleNames.remove(id)?.dispose();
      _vehicleRegistrations.remove(id)?.dispose();
    }
    for (final vehicle in profile.vehicles) {
      _nameController(vehicle).text = vehicle.name;
      _registrationController(vehicle).text = vehicle.registration;
    }
  }

  void _addVehicle() {
    final name = _newVehicleName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the vehicle a name.');
      return;
    }
    if (_vehicles.length >= maxVehicles) {
      setState(() => _error = 'You can save up to 5 vehicles.');
      return;
    }
    final draft = Vehicle(
      id: 'draft-${_drafts++}',
      name: name,
      type: _newVehicleType,
      registration: _newVehicleRegistration.text.trim(),
    );
    setState(() {
      _vehicles = [..._vehicles, draft];
      _nameController(draft);
      _registrationController(draft);
      _newVehicleName.clear();
      _newVehicleRegistration.clear();
      _error = null;
    });
  }

  void _removeVehicle(String id) {
    _vehicleNames.remove(id)?.dispose();
    _vehicleRegistrations.remove(id)?.dispose();
    setState(() {
      _vehicles = [
        for (final vehicle in _vehicles)
          if (vehicle.id != id) vehicle,
      ];
    });
  }

  Future<void> _save() async {
    final accountId = ref.read(sessionProvider)?.id;
    if (accountId == null || _saving) {
      return;
    }
    _savedNotice?.cancel();
    setState(() {
      _saving = true;
      _error = null;
      _savedMessage = null;
    });
    final result = await ref
        .read(saveCustomerProfileProvider)
        .call(
          accountId: accountId,
          firstName: _firstName.text,
          surname: _surname.text,
          address: _address.text,
          contactNumber: _contactNumber.text,
          vehicles: [
            for (final vehicle in _vehicles)
              VehicleInput(
                id: vehicle.id,
                name: _nameController(vehicle).text,
                type: vehicle.type,
                registration: _registrationController(vehicle).text,
              ),
          ],
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success(:final value):
        setState(() {
          _saving = false;
          _hydrated = true;
          _savedMessage = 'Your settings have been saved.';
          _hydrate(value);
        });
        _savedNotice = Timer(const Duration(seconds: 4), () {
          if (!mounted) {
            return;
          }
          setState(() => _savedMessage = null);
        });
        ref.invalidate(profileProvider);
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = profileFailureMessage(error);
          _savedMessage = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final accountId = ref.watch(sessionProvider)?.id;
    if (accountId != _accountId) {
      _accountId = accountId;
      _hydrated = false;
      _savedNotice?.cancel();
      _savedMessage = null;
    }
    if (profile.hasValue &&
        !profile.isLoading &&
        !_hydrated &&
        accountId != null) {
      _hydrated = true;
      _hydrate(profile.requireValue);
    }

    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: const [SignOutButton()],
      ),
      body: AsyncView(
        value: profile,
        data: (_) {
          return ListView(
            padding: pagePadding,
            children: [
              Text(
                widget.includeVehicles
                    ? 'Save your name, how to reach you, and the vehicles a car wash is priced for.'
                    : 'Save your name and how neighbours can reach you.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: const Key('profile-contact-details'),
                  initiallyExpanded: true,
                  title: Text('Contact details', style: textTheme.titleMedium),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      key: const Key('profile-name-field'),
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('profile-surname-field'),
                      controller: _surname,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Surname'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('address-field'),
                      controller: _address,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('contact-number-field'),
                      controller: _contactNumber,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.includeVehicles) ...[
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: const Key('profile-vehicles'),
                    initiallyExpanded: true,
                    title: Text('Vehicles', style: textTheme.titleMedium),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        'Add up to $maxVehicles. Hatch, sedan, and SUV are priced differently.',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final vehicle in _vehicles) ...[
                        _VehicleEditor(
                          vehicle: vehicle,
                          nameController: _nameController(vehicle),
                          registrationController: _registrationController(
                            vehicle,
                          ),
                          onTypeChanged: (type) {
                            setState(() {
                              _vehicles = [
                                for (final item in _vehicles)
                                  if (item.id == vehicle.id)
                                    Vehicle(
                                      id: item.id,
                                      name: item.name,
                                      type: type,
                                      registration: item.registration,
                                    )
                                  else
                                    item,
                              ];
                            });
                          },
                          onRemove: () => _removeVehicle(vehicle.id),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_vehicles.length < maxVehicles) ...[
                        TextField(
                          key: const Key('new-vehicle-name'),
                          controller: _newVehicleName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('new-vehicle-registration'),
                          controller: _newVehicleRegistration,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Registration',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in VehicleType.values)
                              ChoiceChip(
                                key: ValueKey('vehicle-type-${type.name}'),
                                label: Text(vehicleTypeLabel(type)),
                                selected: _newVehicleType == type,
                                onSelected: (_) {
                                  setState(() => _newVehicleType = type);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const Key('add-vehicle'),
                          onPressed: _addVehicle,
                          child: const Text('Add vehicle'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('profile-error'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-profile'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save profile'),
              ),
              if (_savedMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _savedMessage!,
                  key: const Key('profile-saved'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VehicleEditor extends StatelessWidget {
  const _VehicleEditor({
    required this.vehicle,
    required this.nameController,
    required this.registrationController,
    required this.onTypeChanged,
    required this.onRemove,
  });

  final Vehicle vehicle;
  final TextEditingController nameController;
  final TextEditingController registrationController;
  final ValueChanged<VehicleType> onTypeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('profile-vehicle-${vehicle.name}'),
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
                IconButton(
                  key: ValueKey('remove-vehicle-${vehicle.name}'),
                  tooltip: 'Remove vehicle',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('vehicle-registration-${vehicle.id}'),
              controller: registrationController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Registration'),
            ),
            const SizedBox(height: 8),
            DropdownButton<VehicleType>(
              key: ValueKey('vehicle-type-menu-${vehicle.id}'),
              value: vehicle.type,
              isExpanded: true,
              items: [
                for (final type in VehicleType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(vehicleTypeLabel(type)),
                  ),
              ],
              onChanged: (type) {
                if (type != null) {
                  onTypeChanged(type);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
