import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/offerings/domain/save_wash_menu.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/price_parser.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class WashMenuPage extends ConsumerStatefulWidget {
  const WashMenuPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  ConsumerState<WashMenuPage> createState() => _WashMenuPageState();
}

class _WashMenuPageState extends ConsumerState<WashMenuPage> {
  final List<_WashDraft> _drafts = [];
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final providerId = ref.read(sessionProvider)?.providerId;
    if (providerId == null || _saving) {
      return;
    }
    final drafts = <WashDraft>[];
    for (final draft in _drafts) {
      final rates = <VehicleType, VehicleRateDraft>{};
      for (final type in VehicleType.values) {
        final cents = parsePriceToCents(draft.rates[type]!.price.text);
        if (cents == null) {
          setState(() {
            _error = washMenuFailureMessage(WashMenuFailure.invalidPrice);
          });
          return;
        }
        rates[type] = VehicleRateDraft(
          durationHours: draft.rates[type]!.hours,
          priceCents: cents,
        );
      }
      final hatch = rates[VehicleType.hatch]!;
      drafts.add(
        WashDraft(
          id: draft.id,
          name: draft.name.text,
          durationHours: hatch.durationHours,
          priceCents: hatch.priceCents,
          description: draft.description.text,
          rates: rates,
        ),
      );
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(saveWashMenuProvider)
        .call(
          providerId: providerId,
          serviceId: widget.serviceId,
          washes: drafts,
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        ref.invalidate(
          washesProvider(
            WashQuery(providerId: providerId, serviceId: widget.serviceId),
          ),
        );
        context.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = washMenuFailureMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerId = ref.watch(sessionProvider)?.providerId;
    final textTheme = Theme.of(context).textTheme;
    if (providerId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in as a provider.')),
      );
    }
    final washes = ref.watch(
      washesProvider(
        WashQuery(providerId: providerId, serviceId: widget.serviceId),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Edit service')),
      body: AsyncView(
        value: washes,
        data: (items) {
          if (!_loaded) {
            _loaded = true;
            _drafts.addAll(items.map(_WashDraft.fromWash));
          }
          return ListView(
            key: const Key('wash-menu-list'),
            padding: pagePadding,
            children: [
              Text('Car wash', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Add the washes you offer. Set a duration of 1 to 4 hours and a price in rands (R) for a hatch, a sedan, and an SUV.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (var index = 0; index < _drafts.length; index++) ...[
                _WashEditor(
                  index: index,
                  draft: _drafts[index],
                  onChanged: () => setState(() => _error = null),
                  onRemove: () {
                    setState(() {
                      _drafts.removeAt(index).dispose();
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton(
                key: const Key('add-wash'),
                onPressed: () {
                  setState(() {
                    _drafts.add(_WashDraft(expanded: true));
                    _error = null;
                  });
                },
                child: const Text('Add a wash'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  key: const Key('wash-menu-error'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-washes'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save washes'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WashEditor extends StatelessWidget {
  const _WashEditor({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _WashDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = draft.name.text.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('expand-wash-$index'),
        initiallyExpanded: draft.expanded,
        title: Text(title.isEmpty ? 'New wash' : title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: ValueKey('wash-name-$index'),
                controller: draft.name,
                decoration: const InputDecoration(labelText: 'Wash'),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('wash-description-$index'),
                controller: draft.description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What it includes',
                ),
                onChanged: (_) => onChanged(),
              ),
              for (final type in VehicleType.values) ...[
                const SizedBox(height: 16),
                Text(
                  vehicleTypeLabel(type),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hours in washDurationHours)
                      ChoiceChip(
                        key: ValueKey('wash-hours-$index-${type.name}-$hours'),
                        label: Text(formatHours(hours)),
                        selected: draft.rates[type]!.hours == hours,
                        onSelected: (_) {
                          draft.rates[type]!.hours = hours;
                          onChanged();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey('wash-price-$index-${type.name}'),
                  controller: draft.rates[type]!.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${vehicleTypeLabel(type)} price (R)',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: ValueKey('remove-wash-$index'),
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _TypeRate {
  _TypeRate({required this.hours, required String price})
    : price = TextEditingController(text: price);

  int hours;
  final TextEditingController price;

  void dispose() {
    price.dispose();
  }
}

final class _WashDraft {
  _WashDraft({
    this.id,
    String name = '',
    String description = '',
    Map<VehicleType, _TypeRate>? rates,
    this.expanded = false,
  }) : name = TextEditingController(text: name),
       description = TextEditingController(text: description),
       rates =
           rates ??
           {
             for (final type in VehicleType.values)
               type: _TypeRate(hours: 1, price: ''),
           };

  factory _WashDraft.fromWash(WashOption wash) {
    return _WashDraft(
      id: wash.id,
      name: wash.name,
      description: wash.description,
      rates: {
        for (final type in VehicleType.values)
          type: _TypeRate(
            hours: wash.rateFor(type).durationHours,
            price: formatPrice(wash.rateFor(type).priceCents),
          ),
      },
    );
  }

  final String? id;
  final bool expanded;
  final TextEditingController name;
  final TextEditingController description;
  final Map<VehicleType, _TypeRate> rates;

  void dispose() {
    name.dispose();
    description.dispose();
    for (final rate in rates.values) {
      rate.dispose();
    }
  }
}
