import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/service_icon.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

Widget? _serviceActions(
  BuildContext context,
  WidgetRef ref,
  ServiceProvider? provider,
  CommunityService service,
) {
  final active = provider == null || provider.isActive(service.id);
  final delete = provider != null && !active;
  if (!delete && provider == null) {
    return null;
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (delete)
        TextButton(
          key: ValueKey('delete-service-${service.id}'),
          onPressed: () => _deleteService(context, ref, provider, service),
          child: const Text('Delete service'),
        ),
      TextButton(
        key: ValueKey('edit-service-${service.id}'),
        onPressed: () => context.push('/provider/offer/${service.id}'),
        child: const Text('Edit service'),
      ),
    ],
  );
}

bool _active(AsyncValue<ServiceProvider?>? business, CommunityService service) {
  final provider = business?.asData?.value;
  if (provider == null) {
    return true;
  }
  return provider.isActive(service.id);
}

Future<void> _setServiceActive(
  WidgetRef ref,
  ServiceProvider provider,
  String serviceId,
  bool active,
) async {
  await ref
      .read(catalogRepositoryProvider)
      .saveProvider(provider.withServiceActive(serviceId, active));
  ref.invalidate(providerByIdProvider(provider.id));
  ref.invalidate(providerServicesProvider);
  ref.invalidate(providersForServiceProvider);
}

Future<void> _deleteService(
  BuildContext context,
  WidgetRef ref,
  ServiceProvider provider,
  CommunityService service,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete this service?'),
        content: Text('${service.name} will be removed from your services.'),
        actions: [
          TextButton(
            key: const Key('keep-service'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep service'),
          ),
          FilledButton(
            key: const Key('confirm-delete-service'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete service'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) {
    return;
  }
  await ref
      .read(catalogRepositoryProvider)
      .saveProvider(provider.withoutService(service.id));
  await ref
      .read(washRepositoryProvider)
      .replaceWashes(
        providerId: provider.id,
        serviceId: service.id,
        washes: const [],
      );
  ref.invalidate(providerByIdProvider(provider.id));
  ref.invalidate(providerServicesProvider);
  ref.invalidate(providersForServiceProvider);
  ref.invalidate(servicesProvider);
  ref.invalidate(
    washesProvider(WashQuery(providerId: provider.id, serviceId: service.id)),
  );
}

class ProviderHomePage extends ConsumerWidget {
  const ProviderHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionProvider);
    final name = account?.displayName;
    final services = ref.watch(providerServicesProvider);
    final business = account?.providerId == null
        ? null
        : ref.watch(providerByIdProvider(account!.providerId!));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your work'),
        actions: const [SignOutButton()],
      ),
      body: ListView(
        padding: pagePadding,
        children: [
          Text(
            name == null ? 'Hello' : 'Hello, $name',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The services you offer neighbours in this community.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('offer-service-button'),
            onPressed: () => context.push('/provider/offer'),
            child: const Text('Offer a service'),
          ),
          const SizedBox(height: 28),
          Text('Your services', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          AsyncView(
            expand: false,
            value: services,
            data: (items) {
              if (items.isEmpty) {
                return const Text('You have not published a service yet.');
              }
              return Column(
                children: [
                  for (final service in items) ...[
                    Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(iconForService(service.id)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _ServiceHeading(
                                      providerId: account?.providerId,
                                      service: service,
                                    ),
                                  ),
                                ),
                                ?_serviceActions(
                                  context,
                                  ref,
                                  business?.asData?.value,
                                  service,
                                ),
                              ],
                            ),
                          ),
                          CheckboxListTile(
                            key: ValueKey('service-active-${service.id}'),
                            title: const Text('Active'),
                            subtitle: Text(
                              _active(business, service)
                                  ? 'Customers can book this service.'
                                  : 'Suspended. Customers cannot book this.',
                            ),
                            value: _active(business, service),
                            onChanged: business?.asData?.value == null
                                ? null
                                : (active) => _setServiceActive(
                                    ref,
                                    business!.asData!.value!,
                                    service.id,
                                    active ?? false,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceHeading extends ConsumerWidget {
  const _ServiceHeading({required this.providerId, required this.service});

  final String? providerId;
  final CommunityService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final offeringName = providerId == null
        ? null
        : ref
              .watch(
                offeringProvider(
                  OfferingQuery(providerId: providerId!, serviceId: service.id),
                ),
              )
              .asData
              ?.value
              ?.name
              .trim();
    final serviceName = offeringName == null || offeringName.isEmpty
        ? service.name
        : offeringName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(serviceName, style: textTheme.titleMedium),
        if (serviceName != service.name)
          Text(
            service.name,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
          ),
        Text(service.summary, style: textTheme.bodySmall),
      ],
    );
  }
}
