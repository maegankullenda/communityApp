import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

const demoPassword = 'community';

const alexEmail = 'alex@community.app';
const jordanEmail = 'jordan@community.app';
const samEmail = 'sam@community.app';
const jessEmail = 'jess@community.app';
const rileyEmail = 'riley@community.app';
const maeganEmail = 'maegan@community.app';
const maeganAdminEmail = 'maeganadmin@community.app';

final class DemoAccount {
  const DemoAccount({
    required this.label,
    required this.email,
    required this.detail,
    required this.role,
  });

  final String label;
  final String email;
  final String detail;
  final AccountRole role;
}

const demoAccounts = <DemoAccount>[
  DemoAccount(
    label: 'Alex, customer',
    email: alexEmail,
    detail: 'Browses and books services',
    role: AccountRole.customer,
  ),
  DemoAccount(
    label: 'Jordan, customer',
    email: jordanEmail,
    detail: 'A second customer for booking the same times',
    role: AccountRole.customer,
  ),
  DemoAccount(
    label: 'Sam, car wash',
    email: samEmail,
    detail: "Sees bookings for Sam's Shine",
    role: AccountRole.provider,
  ),
  DemoAccount(
    label: 'Jess, foodie',
    email: jessEmail,
    detail: "Sees orders for Jess's Kitchen",
    role: AccountRole.provider,
  ),
  DemoAccount(
    label: 'Riley, beauty',
    email: rileyEmail,
    detail: 'Sees bookings for Riley Studio',
    role: AccountRole.provider,
  ),
  DemoAccount(
    label: "Maegan, car wash",
    email: maeganEmail,
    detail: "Sees bookings for Maegan's Rides",
    role: AccountRole.provider,
  ),
  DemoAccount(
    label: 'Maegan, admin',
    email: maeganAdminEmail,
    detail: 'Adds categories and can suspend providers',
    role: AccountRole.admin,
  ),
];

CommunityStore seedCommunity({DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final weekEnd = today.add(const Duration(days: 7));

  final accounts = <String, Account>{
    'alex': const Account(
      id: 'alex',
      email: alexEmail,
      displayName: 'Alex',
      role: AccountRole.customer,
    ),
    'jordan': const Account(
      id: 'jordan',
      email: jordanEmail,
      displayName: 'Jordan',
      role: AccountRole.customer,
    ),
    'sam': const Account(
      id: 'sam',
      email: samEmail,
      displayName: 'Sam',
      role: AccountRole.provider,
      providerId: 'sam-shine',
    ),
    'jess': const Account(
      id: 'jess',
      email: jessEmail,
      displayName: 'Jess',
      role: AccountRole.provider,
      providerId: 'jess-kitchen',
    ),
    'riley': const Account(
      id: 'riley',
      email: rileyEmail,
      displayName: 'Riley',
      role: AccountRole.provider,
      providerId: 'riley-studio',
    ),
    'maegan': const Account(
      id: 'maegan',
      email: maeganEmail,
      displayName: 'Maegan',
      role: AccountRole.provider,
      providerId: 'maegans-rides',
    ),
    'maegan-admin': const Account(
      id: 'maegan-admin',
      email: maeganAdminEmail,
      displayName: 'Maegan Admin',
      role: AccountRole.admin,
    ),
  };

  final services = <String, CommunityService>{
    'car-wash': const CommunityService(
      id: 'car-wash',
      name: 'Car wash',
      summary: 'Book a wash at a time that suits you.',
      fulfillment: FulfillmentKind.appointment,
    ),
    'foodie': const CommunityService(
      id: 'foodie',
      name: 'Foodie',
      summary: 'Order meals cooks have planned for the day or week.',
      fulfillment: FulfillmentKind.order,
    ),
    'beauty': const CommunityService(
      id: 'beauty',
      name: 'Beauty',
      summary: 'Reserve a treatment with someone nearby.',
      fulfillment: FulfillmentKind.appointment,
    ),
  };

  final providers = <String, ServiceProvider>{
    'sam-shine': const ServiceProvider(
      id: 'sam-shine',
      displayName: "Sam's Shine",
      bio: 'Driveway and mobile washes, booked by the hour.',
      serviceIds: {'car-wash'},
    ),
    'maegans-rides': const ServiceProvider(
      id: 'maegans-rides',
      displayName: "Maegan's Rides",
      bio: 'Exterior and interior washes, with a rinse while you wait.',
      serviceIds: {'car-wash'},
    ),
    'jess-kitchen': const ServiceProvider(
      id: 'jess-kitchen',
      displayName: "Jess's Kitchen",
      bio: 'Home-cooked meals for the week.',
      serviceIds: {'foodie'},
    ),
    'riley-studio': const ServiceProvider(
      id: 'riley-studio',
      displayName: 'Riley Studio',
      bio: 'Cuts, colour, and treatments.',
      serviceIds: {'beauty'},
    ),
  };

  final slots = <String, TimeSlot>{
    for (final slot in [
      ..._appointmentSlots(
        today: today,
        providerId: 'sam-shine',
        serviceId: 'car-wash',
      ),
      ..._appointmentSlots(
        today: today,
        providerId: 'maegans-rides',
        serviceId: 'car-wash',
      ),
      ..._appointmentSlots(
        today: today,
        providerId: 'riley-studio',
        serviceId: 'beauty',
      ),
    ])
      slot.id: slot,
  };

  final menuItems = <String, MenuItem>{
    'lentil-stew': MenuItem(
      id: 'lentil-stew',
      providerId: 'jess-kitchen',
      serviceId: 'foodie',
      name: 'Lentil stew',
      description: 'Slow-cooked lentils with warm spices.',
      priceCents: 8500,
      availableFrom: today,
      availableUntil: weekEnd,
    ),
    'chicken-bowl': MenuItem(
      id: 'chicken-bowl',
      providerId: 'jess-kitchen',
      serviceId: 'foodie',
      name: 'Herb chicken bowl',
      description: 'Roasted chicken, greens, and grains.',
      priceCents: 9200,
      availableFrom: today,
      availableUntil: weekEnd,
    ),
    'veggie-wrap': MenuItem(
      id: 'veggie-wrap',
      providerId: 'jess-kitchen',
      serviceId: 'foodie',
      name: 'Market veggie wrap',
      description: 'Seasonal vegetables and hummus.',
      priceCents: 6800,
      availableFrom: today,
      availableUntil: weekEnd,
    ),
  };

  return CommunityStore(
    accounts: accounts,
    passwordsByEmail: {
      for (final account in accounts.values) account.email: demoPassword,
    },
    services: services,
    providers: providers,
    slots: slots,
    menuItems: menuItems,
    washes: {
      for (final wash in maeganWashes) wash.id: wash,
    },
  );
}

const maeganWashes = [
  WashOption(
    id: 'wash-quick',
    providerId: 'maegans-rides',
    serviceId: 'car-wash',
    name: 'Quick wash',
    duration: Duration(hours: 1),
    priceCents: 15000,
    description: 'Wash and wipe exterior and tyre polish',
  ),
  WashOption(
    id: 'wash-full',
    providerId: 'maegans-rides',
    serviceId: 'car-wash',
    name: 'Full wash',
    duration: Duration(hours: 2),
    priceCents: 28000,
    description:
        'Wash and wipe exterior, interior vacuum, dash shine and tyre polish',
  ),
  WashOption(
    id: 'wash-wax',
    providerId: 'maegans-rides',
    serviceId: 'car-wash',
    name: 'Wax and detailing',
    duration: Duration(hours: 4),
    priceCents: 45000,
    description: 'Full wash with Macguires polish and detailing',
  ),
];

List<TimeSlot> _appointmentSlots({
  required DateTime today,
  required String providerId,
  required String serviceId,
}) {
  final slots = <TimeSlot>[];
  for (final day in openingDays(today)) {
    for (final hour in openingHoursFor(serviceId)) {
      final start = DateTime(day.year, day.month, day.day, hour);
      slots.add(
        TimeSlot(
          id: _slotId(
            serviceId: serviceId,
            providerId: providerId,
            start: start,
          ),
          providerId: providerId,
          serviceId: serviceId,
          start: start,
          duration: const Duration(hours: 1),
          capacity: 1,
        ),
      );
    }
  }
  return slots;
}

String _slotId({
  required String serviceId,
  required String providerId,
  required DateTime start,
}) {
  final month = start.month.toString().padLeft(2, '0');
  final day = start.day.toString().padLeft(2, '0');
  final hour = start.hour.toString().padLeft(2, '0');
  final minute = start.minute.toString().padLeft(2, '0');
  return '$serviceId-$providerId-${start.year}$month$day-$hour$minute';
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
