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

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(catalogServicesProvider);
    final providers = ref.watch(allProvidersProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: const [SignOutButton()],
      ),
      body: ListView(
        padding: pagePadding,
        children: [
          Text('Categories', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Turn a category off to hide it from customers. Add one when the community needs a new kind of service.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('add-category'),
              onPressed: () => context.push('/admin/category'),
              child: const Text('Add category'),
            ),
          ),
          const SizedBox(height: 12),
          AsyncView(
            expand: false,
            value: categories,
            data: (items) {
              return Column(
                children: [
                  for (final service in items) ...[
                    CheckboxListTile(
                      key: ValueKey('category-active-${service.id}'),
                      secondary: Icon(iconForService(service.id)),
                      title: Text(service.name),
                      subtitle: Text(
                        service.active
                            ? 'Customers can browse this category.'
                            : 'Hidden. Customers cannot browse this.',
                      ),
                      value: service.active,
                      onChanged: (active) =>
                          _setCategoryActive(ref, service, active ?? false),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Service providers', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Turn a provider off to stop customers booking them.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          AsyncView(
            expand: false,
            value: providers,
            data: (items) {
              return Column(
                children: [
                  for (final provider in items) ...[
                    CheckboxListTile(
                      key: ValueKey('provider-active-${provider.id}'),
                      title: Text(provider.displayName),
                      subtitle: Text(
                        provider.active
                            ? 'Customers can book this provider.'
                            : 'Suspended. Customers cannot book this provider.',
                      ),
                      value: provider.active,
                      onChanged: (active) =>
                          _setProviderActive(ref, provider, active ?? false),
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

Future<void> _setCategoryActive(
  WidgetRef ref,
  CommunityService service,
  bool active,
) async {
  await ref
      .read(catalogRepositoryProvider)
      .saveService(service.withActive(active));
  ref.invalidate(catalogServicesProvider);
  ref.invalidate(servicesProvider);
  ref.invalidate(providersForServiceProvider);
}

Future<void> _setProviderActive(
  WidgetRef ref,
  ServiceProvider provider,
  bool active,
) async {
  await ref
      .read(catalogRepositoryProvider)
      .saveProvider(provider.withActive(active));
  ref.invalidate(allProvidersProvider);
  ref.invalidate(providerByIdProvider(provider.id));
  ref.invalidate(providersForServiceProvider);
}
