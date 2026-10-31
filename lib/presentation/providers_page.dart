import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class ProvidersPage extends ConsumerWidget {
  const ProvidersPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceByIdProvider(serviceId));
    final providers = ref.watch(providersForServiceProvider(serviceId));
    final offerings = ref.watch(offeringsForServiceProvider(serviceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Providers')),
      body: AsyncView(
        value: service,
        data: (found) {
          if (found == null) {
            return const _Missing(message: 'That service is not listed.');
          }
          return AsyncView(
            value: providers,
            data: (people) {
              final named = {
                for (final offering
                    in offerings.asData?.value ?? const <ServiceOffering>[])
                  offering.providerId: offering,
              };
              return ListView(
                padding: pagePadding,
                children: [
                  Text(
                    found.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    found.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Providers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (people.isEmpty)
                    const Text('Nobody is offering this yet.')
                  else
                    for (final provider in people) ...[
                      _ProviderCard(
                        service: found,
                        provider: provider,
                        offering: named[provider.id],
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.service,
    required this.provider,
    required this.offering,
  });

  final CommunityService service;
  final ServiceProvider provider;
  final ServiceOffering? offering;

  @override
  Widget build(BuildContext context) {
    final appointment = service.fulfillment == FulfillmentKind.appointment;
    return Card(
      child: InkWell(
        key: ValueKey('provider-${provider.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/services/${service.id}/providers/${provider.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offering?.name ?? provider.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                (offering?.description.isNotEmpty ?? false)
                    ? offering!.description
                    : provider.bio,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                appointment ? 'See times' : 'See menu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
