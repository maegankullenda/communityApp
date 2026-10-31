import 'package:flutter/material.dart';

import 'package:community_app/presentation/format.dart';

class DayTabs extends StatelessWidget {
  const DayTabs({
    required this.days,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          return ChoiceChip(
            key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
            label: Text(formatDay(day)),
            selected: day == selected,
            onSelected: (_) => onSelected(day),
          );
        },
      ),
    );
  }
}
