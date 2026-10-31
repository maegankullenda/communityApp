import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/data/community_store.dart';
import 'package:community_app/data/in_memory_auth_repository.dart';
import 'package:community_app/data/in_memory_catalog_repository.dart';
import 'package:community_app/data/in_memory_offering_repository.dart';
import 'package:community_app/data/in_memory_notification_repository.dart';
import 'package:community_app/data/in_memory_ordering_repository.dart';
import 'package:community_app/data/in_memory_profile_repository.dart';
import 'package:community_app/data/in_memory_scheduling_repository.dart';
import 'package:community_app/data/in_memory_wash_repository.dart';
import 'package:community_app/data/seed_community.dart';
import 'package:community_app/features/activity/domain/load_my_activity.dart';
import 'package:community_app/features/activity/domain/load_provider_bookings.dart';
import 'package:community_app/features/catalog/domain/register_service.dart';
import 'package:community_app/features/identity/domain/sign_in.dart';
import 'package:community_app/features/notifications/domain/record_booking_notice.dart';
import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/save_wash_menu.dart';
import 'package:community_app/features/ordering/domain/place_order.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/save_customer_profile.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/book_appointment.dart';
import 'package:community_app/features/scheduling/domain/change_appointment.dart';
import 'package:community_app/core/result.dart';

final class AppHarness {
  AppHarness({DateTime? now})
    : clock = FixedClock(now ?? DateTime(2026, 10, 5, 8)),
      ids = SequentialIdGenerator() {
    store = seedCommunity(now: clock.instant);
    catalog = InMemoryCatalogRepository(store);
    scheduling = InMemorySchedulingRepository(store);
    washes = InMemoryWashRepository(store);
    offerings = InMemoryOfferingRepository(store);
    ordering = InMemoryOrderingRepository(store);
    profiles = InMemoryProfileRepository(store);
    auth = InMemoryAuthRepository(store);
    notifications = InMemoryNotificationRepository(store, clock: clock);
    notices = RecordBookingNotice(
      notifications: notifications,
      profiles: profiles,
      catalog: catalog,
      offerings: offerings,
      auth: auth,
      ids: ids,
      clock: clock,
    );
    signIn = SignIn(auth);
    signOut = SignOut(auth);
    registerService = RegisterService(catalog);
    saveProfile = SaveCustomerProfile(profiles: profiles, ids: ids);
    bookAppointment = BookAppointment(
      scheduling: scheduling,
      profiles: profiles,
      washes: washes,
      offerings: offerings,
      catalog: catalog,
      ids: ids,
      clock: clock,
      notices: notices,
    );
    changeAppointment = ChangeAppointment(
      scheduling: scheduling,
      profiles: profiles,
      washes: washes,
      offerings: offerings,
      clock: clock,
      notices: notices,
    );
    saveWashMenu = SaveWashMenu(washes: washes, ids: ids);
    cancelAppointment = CancelAppointment(scheduling);
    declineAppointment = DeclineAppointment(
      scheduling: scheduling,
      notices: notices,
    );
    placeOrder = PlaceOrder(ordering: ordering, ids: ids, clock: clock);
    offerService = OfferService(
      catalog: catalog,
      scheduling: scheduling,
      ordering: ordering,
      offerings: offerings,
      ids: ids,
      clock: clock,
    );
    loadMyActivity = LoadMyActivity(
      scheduling: scheduling,
      ordering: ordering,
      catalog: catalog,
      offerings: offerings,
    );
    loadProviderBookings = LoadProviderBookings(
      scheduling: scheduling,
      catalog: catalog,
      auth: auth,
      profiles: profiles,
    );
  }

  final FixedClock clock;
  final SequentialIdGenerator ids;
  late final CommunityStore store;
  late final InMemoryCatalogRepository catalog;
  late final InMemorySchedulingRepository scheduling;
  late final InMemoryWashRepository washes;
  late final InMemoryOfferingRepository offerings;
  late final InMemoryOrderingRepository ordering;
  late final InMemoryProfileRepository profiles;
  late final InMemoryAuthRepository auth;
  late final InMemoryNotificationRepository notifications;
  late final RecordBookingNotice notices;
  late final SignIn signIn;
  late final SignOut signOut;
  late final RegisterService registerService;
  late final SaveCustomerProfile saveProfile;
  late final BookAppointment bookAppointment;
  late final ChangeAppointment changeAppointment;
  late final SaveWashMenu saveWashMenu;
  late final CancelAppointment cancelAppointment;
  late final DeclineAppointment declineAppointment;
  late final PlaceOrder placeOrder;
  late final OfferService offerService;
  late final LoadMyActivity loadMyActivity;
  late final LoadProviderBookings loadProviderBookings;

  Future<String> ensureVehicle(
    String accountId, {
    String name = 'Daily',
    VehicleType type = VehicleType.hatch,
  }) async {
    final existing = await profiles.find(accountId);
    for (final vehicle in existing.vehicles) {
      if (vehicle.name == name && vehicle.type == type) {
        return vehicle.id;
      }
    }
    final saved = await saveProfile.call(
      accountId: accountId,
      firstName: existing.firstName,
      surname: existing.surname,
      address: existing.address,
      contactNumber: existing.contactNumber.isEmpty
          ? '0821234567'
          : existing.contactNumber,
      vehicles: [
        for (final vehicle in existing.vehicles)
          VehicleInput(
            id: vehicle.id,
            name: vehicle.name,
            type: vehicle.type,
            registration: vehicle.registration,
          ),
        VehicleInput(name: name, type: type),
      ],
    );
    final profile = switch (saved) {
      Success(:final value) => value,
      Err(:final error) => throw StateError('Could not save vehicle: $error'),
    };
    return profile.vehicles.last.id;
  }
}
