import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/presentation/format.dart';

const _ink = Color(0xFF1C2B24);
const _line = Color(0xFFE4D9C8);
const _openGreen = Color(0xFF1F6B4A);

class BookingCalendar extends StatefulWidget {
  const BookingCalendar({
    required this.bookings,
    required this.initialMonth,
    super.key,
  });

  final List<ProviderBooking> bookings;
  final DateTime initialMonth;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bookedDays = {
      for (final booking in widget.bookings)
        DateTime(
          booking.appointment.start.year,
          booking.appointment.start.month,
          booking.appointment.start.day,
        ),
    };
    final firstWeekday = DateTime(_month.year, _month.month).weekday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('booking-month-previous'),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                formatMonth(_month),
                key: const Key('booking-month'),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('booking-month-next'),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E6B64),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var blank = 1; blank < firstWeekday; blank++)
              const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                day: DateTime(_month.year, _month.month, day),
                booked: bookedDays.contains(
                  DateTime(_month.year, _month.month, day),
                ),
              ),
          ],
        ),
        if (widget.bookings.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'No bookings yet. Times you publish show up here once someone books them.',
            style: textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.booked});

  final DateTime day;
  final bool booked;

  @override
  Widget build(BuildContext context) {
    final key = 'booking-day-${day.year}-${day.month}-${day.day}';
    return Material(
      color: booked ? _openGreen : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: booked ? _openGreen : _line),
      ),
      child: InkWell(
        key: ValueKey(booked ? 'booked-$key' : key),
        borderRadius: BorderRadius.circular(10),
        onTap: booked
            ? () {
                final month = day.month.toString().padLeft(2, '0');
                final date = day.day.toString().padLeft(2, '0');
                context.push('/provider/bookings/${day.year}-$month-$date');
              }
            : null,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: booked ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );
  }
}
