import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';

class DeclineBookingPage extends ConsumerStatefulWidget {
  const DeclineBookingPage({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  ConsumerState<DeclineBookingPage> createState() => _DeclineBookingPageState();
}

class _DeclineBookingPageState extends ConsumerState<DeclineBookingPage> {
  final _message = TextEditingController();
  final _from = TextEditingController();
  final _until = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    _from.dispose();
    _until.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: _parseDate(controller.text) ?? now,
    );
    if (picked == null) {
      return;
    }
    controller.text = formatIsoDate(picked);
  }

  Future<void> _decline() async {
    final providerId = ref.read(sessionProvider)?.providerId;
    final from = _parseDate(_from.text);
    final until = _parseDate(_until.text);
    if (providerId == null || _saving) {
      return;
    }
    final fromText = _from.text.trim();
    final untilText = _until.text.trim();
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Tell the customer why this time does not work.');
      return;
    }
    if (fromText.isEmpty != untilText.isEmpty ||
        (fromText.isNotEmpty &&
            (from == null || until == null || until.isBefore(from)))) {
      setState(
        () => _error =
            'Leave both dates empty, or suggest a from date and an until date that is the same day or later.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(declineAppointmentProvider)
        .call(
          providerId: providerId,
          appointmentId: widget.appointmentId,
          message: _message.text,
          suggestedFrom: fromText.isEmpty ? null : from,
          suggestedUntil: untilText.isEmpty ? null : until,
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        invalidateBookingViews(ref);
        context.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = bookingFailureMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Decline booking')),
      body: ListView(
        padding: pagePadding,
        children: [
          Text(
            'Tell the customer why this time does not work. A suggested date range is optional.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('decline-message'),
            controller: _message,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          _DateField(
            fieldKey: const Key('decline-from'),
            pickerKey: const Key('decline-from-picker'),
            label: 'Suggested from (optional)',
            controller: _from,
            onPick: () => _pickDate(_from),
          ),
          const SizedBox(height: 12),
          _DateField(
            fieldKey: const Key('decline-until'),
            pickerKey: const Key('decline-until-picker'),
            label: 'Suggested until (optional)',
            controller: _until,
            onPick: () => _pickDate(_until),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('send-decline'),
            onPressed: _saving ? null : _decline,
            child: Text(_saving ? 'Declining…' : 'Decline booking'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.pickerKey,
    required this.label,
    required this.controller,
    required this.onPick,
  });

  final Key fieldKey;
  final Key pickerKey;
  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'yyyy-mm-dd',
            ),
          ),
        ),
        IconButton(
          key: pickerKey,
          tooltip: 'Choose $label',
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    );
  }
}

DateTime? _parseDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
