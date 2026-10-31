import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';

class CreateCategoryPage extends ConsumerStatefulWidget {
  const CreateCategoryPage({super.key});

  @override
  ConsumerState<CreateCategoryPage> createState() => _CreateCategoryPageState();
}

class _CreateCategoryPageState extends ConsumerState<CreateCategoryPage> {
  final _name = TextEditingController();
  final _summary = TextEditingController();
  FulfillmentKind _kind = FulfillmentKind.appointment;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(createCategoryProvider)
        .call(name: _name.text, summary: _summary.text, fulfillment: _kind);
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        ref.invalidate(catalogServicesProvider);
        ref.invalidate(servicesProvider);
        context.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = createCategoryFailureMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add category')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: pagePadding,
              children: [
                Text(
                  'Customers browse categories, then choose a provider. Providers cannot create a category themselves.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('category-name-field'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('category-summary-field'),
                  controller: _summary,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<FulfillmentKind>(
                  segments: const [
                    ButtonSegment(
                      value: FulfillmentKind.appointment,
                      label: Text('Appointment'),
                    ),
                    ButtonSegment(
                      value: FulfillmentKind.order,
                      label: Text('Order'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) {
                    setState(() => _kind = selection.first);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('category-error'),
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
              key: const Key('save-category'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save category'),
            ),
          ),
        ],
      ),
    );
  }
}
