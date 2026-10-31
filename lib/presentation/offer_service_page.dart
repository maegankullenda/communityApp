import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class OfferServicePage extends ConsumerStatefulWidget {
  const OfferServicePage({super.key});

  @override
  ConsumerState<OfferServicePage> createState() => _OfferServicePageState();
}

class _OfferServicePageState extends ConsumerState<OfferServicePage> {
  String? _serviceId;
  String? _error;

  void _continue(List<CommunityService> services) {
    final selected = services.where((service) => service.id == _serviceId);
    if (selected.isEmpty) {
      setState(() => _error = 'Choose a service category.');
      return;
    }
    context.push('/provider/offer/${selected.first.id}');
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Offer a service')),
      body: AsyncView(
        value: services,
        data: (items) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: pagePadding,
                  children: [
                    Text(
                      'Choose a service category. Next you will name the service you provide.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final service in items)
                      RadioListTile<String>(
                        key: ValueKey('offer-category-${service.id}'),
                        value: service.id,
                        groupValue: _serviceId,
                        title: Text(service.name),
                        subtitle: Text(service.summary),
                        onChanged: (value) {
                          setState(() => _serviceId = value);
                        },
                      ),
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
                  ],
                ),
              ),
              Padding(
                padding: pagePadding,
                child: FilledButton(
                  key: const Key('continue-offer'),
                  onPressed: () => _continue(items),
                  child: const Text('Continue'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
