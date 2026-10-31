import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

/// Process-local stand-in for a backend. Tests share one store so a booking
/// made by a customer is visible to the provider in the same session. Device
/// builds use the Postgres API instead of this store.
///
/// Passwords are plain text because this store never leaves the device.
/// A real backend would store a password hash and issue a session token.
final class CommunityStore {
  CommunityStore({
    required this.accounts,
    required this.passwordsByEmail,
    required this.services,
    required this.providers,
    required this.slots,
    required this.menuItems,
    Map<String, Appointment>? appointments,
    Map<String, CustomerOrder>? orders,
    Map<String, CustomerProfile>? profiles,
    Map<String, WashOption>? washes,
    Map<String, ServiceOffering>? offerings,
    Map<String, Treatment>? treatments,
    Map<String, AppNotification>? notifications,
  }) : appointments = appointments ?? <String, Appointment>{},
       orders = orders ?? <String, CustomerOrder>{},
       profiles = profiles ?? <String, CustomerProfile>{},
       washes = washes ?? <String, WashOption>{},
       offerings = offerings ?? <String, ServiceOffering>{},
       treatments = treatments ?? <String, Treatment>{},
       notifications = notifications ?? <String, AppNotification>{};

  final Map<String, Account> accounts;
  final Map<String, String> passwordsByEmail;
  final Map<String, CommunityService> services;
  final Map<String, ServiceProvider> providers;
  final Map<String, TimeSlot> slots;
  final Map<String, MenuItem> menuItems;
  final Map<String, Appointment> appointments;
  final Map<String, CustomerOrder> orders;
  final Map<String, CustomerProfile> profiles;
  final Map<String, WashOption> washes;
  final Map<String, ServiceOffering> offerings;
  final Map<String, Treatment> treatments;
  final Map<String, AppNotification> notifications;

  Account? session;
}
