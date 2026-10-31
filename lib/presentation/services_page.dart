import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/service_icon.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider)?.displayName;
    final services = ref.watch(servicesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        actions: const [SignOutButton()],
      ),
      body: AsyncView(
        value: services,
        data: (items) {
          return ListView(
            padding: pagePadding,
            children: [
              Text(
                name == null ? 'Hello' : 'Hello, $name',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'What services are you looking for in this community?',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (final service in items) ...[
                _ServiceCard(service: service),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final CommunityService service;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        key: ValueKey('open-service-${service.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/services/${service.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  iconForService(service.id),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(service.summary, style: textTheme.bodySmall),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
