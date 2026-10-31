import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/data/community_store.dart';
import 'package:community_app/data/http_repositories.dart';
import 'package:community_app/data/api/community_api.dart';
import 'package:community_app/data/in_memory_auth_repository.dart';
import 'package:community_app/data/in_memory_catalog_repository.dart';
import 'package:community_app/data/in_memory_offering_repository.dart';
import 'package:community_app/data/in_memory_notification_repository.dart';
import 'package:community_app/data/in_memory_ordering_repository.dart';
import 'package:community_app/data/in_memory_profile_repository.dart';
import 'package:community_app/data/in_memory_scheduling_repository.dart';
import 'package:community_app/data/in_memory_wash_repository.dart';
import 'package:community_app/data/seed_community.dart';
import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/activity/domain/load_my_activity.dart';
import 'package:community_app/features/activity/domain/load_provider_bookings.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/create_category.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/register_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';
import 'package:community_app/features/identity/domain/sign_in.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/notifications/domain/notification_repository.dart';
import 'package:community_app/features/notifications/domain/record_booking_notice.dart';
import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/update_offering.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/save_wash_menu.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/ordering/domain/place_order.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/profile/domain/save_customer_profile.dart';
import 'package:community_app/features/scheduling/domain/book_appointment.dart';
import 'package:community_app/features/scheduling/domain/change_appointment.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => TimeBasedIdGenerator(),
);

/// Null in tests, so they keep the in-memory store. Device builds set the
/// Postgres API address from `main`.
final apiBaseUrlProvider = Provider<String?>((ref) => null);

final communityApiProvider = Provider<CommunityApi>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl == null || baseUrl.isEmpty) {
    throw StateError('The API is only used when a base URL is configured.');
  }
  final api = CommunityApi(baseUrl: baseUrl);
  ref.onDispose(api.close);
  return api;
});

final communityStoreProvider = Provider<CommunityStore>(
  (ref) => seedCommunity(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryAuthRepository(ref.watch(communityStoreProvider));
  }
  return HttpAuthRepository(ref.watch(communityApiProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryCatalogRepository(ref.watch(communityStoreProvider));
  }
  return HttpCatalogRepository(ref.watch(communityApiProvider));
});

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemorySchedulingRepository(ref.watch(communityStoreProvider));
  }
  return HttpSchedulingRepository(ref.watch(communityApiProvider));
});

final offeringRepositoryProvider = Provider<OfferingRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryOfferingRepository(ref.watch(communityStoreProvider));
  }
  return HttpOfferingRepository(ref.watch(communityApiProvider));
});

final washRepositoryProvider = Provider<WashRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryWashRepository(ref.watch(communityStoreProvider));
  }
  return HttpWashRepository(ref.watch(communityApiProvider));
});

final orderingRepositoryProvider = Provider<OrderingRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryOrderingRepository(ref.watch(communityStoreProvider));
  }
  return HttpOrderingRepository(ref.watch(communityApiProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryNotificationRepository(
      ref.watch(communityStoreProvider),
      clock: ref.watch(clockProvider),
    );
  }
  return HttpNotificationRepository(ref.watch(communityApiProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (!_usesApi(ref)) {
    return InMemoryProfileRepository(ref.watch(communityStoreProvider));
  }
  return HttpProfileRepository(ref.watch(communityApiProvider));
});

bool _usesApi(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return baseUrl != null && baseUrl.isNotEmpty;
}

final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.watch(authRepositoryProvider));
});

final registerServiceProvider = Provider<RegisterService>((ref) {
  return RegisterService(ref.watch(catalogRepositoryProvider));
});

final recordBookingNoticeProvider = Provider<RecordBookingNotice>((ref) {
  return RecordBookingNotice(
    notifications: ref.watch(notificationRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final bookAppointmentProvider = Provider<BookAppointment>((ref) {
  return BookAppointment(
    scheduling: ref.watch(schedulingRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    washes: ref.watch(washRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    notices: ref.watch(recordBookingNoticeProvider),
  );
});

final changeAppointmentProvider = Provider<ChangeAppointment>((ref) {
  return ChangeAppointment(
    scheduling: ref.watch(schedulingRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    washes: ref.watch(washRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
    clock: ref.watch(clockProvider),
    notices: ref.watch(recordBookingNoticeProvider),
  );
});

final saveWashMenuProvider = Provider<SaveWashMenu>((ref) {
  return SaveWashMenu(
    washes: ref.watch(washRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});

final declineAppointmentProvider = Provider<DeclineAppointment>((ref) {
  return DeclineAppointment(
    scheduling: ref.watch(schedulingRepositoryProvider),
    notices: ref.watch(recordBookingNoticeProvider),
  );
});

final confirmAppointmentProvider = Provider<ConfirmAppointment>((ref) {
  return ConfirmAppointment(
    scheduling: ref.watch(schedulingRepositoryProvider),
    notices: ref.watch(recordBookingNoticeProvider),
  );
});

final cancelAppointmentProvider = Provider<CancelAppointment>((ref) {
  return CancelAppointment(ref.watch(schedulingRepositoryProvider));
});

final placeOrderProvider = Provider<PlaceOrder>((ref) {
  return PlaceOrder(
    ordering: ref.watch(orderingRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final updateOfferingProvider = Provider<UpdateOffering>((ref) {
  return UpdateOffering(
    catalog: ref.watch(catalogRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
    scheduling: ref.watch(schedulingRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final offerServiceProvider = Provider<OfferService>((ref) {
  return OfferService(
    catalog: ref.watch(catalogRepositoryProvider),
    scheduling: ref.watch(schedulingRepositoryProvider),
    ordering: ref.watch(orderingRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

final saveCustomerProfileProvider = Provider<SaveCustomerProfile>((ref) {
  return SaveCustomerProfile(
    profiles: ref.watch(profileRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});

final loadMyActivityProvider = Provider<LoadMyActivity>((ref) {
  return LoadMyActivity(
    scheduling: ref.watch(schedulingRepositoryProvider),
    ordering: ref.watch(orderingRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    offerings: ref.watch(offeringRepositoryProvider),
  );
});

final loadProviderBookingsProvider = Provider<LoadProviderBookings>((ref) {
  return LoadProviderBookings(
    scheduling: ref.watch(schedulingRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
  );
});

final sessionProvider = NotifierProvider<SessionController, Account?>(
  SessionController.new,
);

final class SessionController extends Notifier<Account?> {
  @override
  Account? build() => ref.watch(authRepositoryProvider).currentAccount;

  Future<AuthFailure?> signIn({
    required String email,
    required String password,
  }) async {
    final result = await ref
        .read(signInProvider)
        .call(email: email, password: password);
    switch (result) {
      case Success():
        state = result.value;
        return null;
      case Err(:final error):
        return error;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final createCategoryProvider = Provider<CreateCategory>((ref) {
  return CreateCategory(ref.watch(catalogRepositoryProvider));
});

final catalogServicesProvider = FutureProvider<List<CommunityService>>((ref) {
  return ref.watch(catalogRepositoryProvider).listServices();
});

final servicesProvider = FutureProvider<List<CommunityService>>((ref) async {
  final services = await ref.watch(catalogServicesProvider.future);
  return [
    for (final service in services)
      if (service.active) service,
  ];
});

final allProvidersProvider = FutureProvider<List<ServiceProvider>>((ref) {
  return ref.watch(catalogRepositoryProvider).listProviders();
});

final serviceByIdProvider = FutureProvider.family<CommunityService?, String>((
  ref,
  id,
) {
  return ref.watch(catalogRepositoryProvider).findService(id);
});

final providerByIdProvider = FutureProvider.family<ServiceProvider?, String>((
  ref,
  id,
) {
  return ref.watch(catalogRepositoryProvider).findProvider(id);
});

final providersForServiceProvider =
    FutureProvider.family<List<ServiceProvider>, String>((ref, serviceId) {
      return ref.watch(catalogRepositoryProvider).providersFor(serviceId);
    });

final class SlotQuery {
  const SlotQuery({
    required this.serviceId,
    required this.providerId,
    required this.from,
    required this.to,
  });

  final String serviceId;
  final String providerId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) {
    return other is SlotQuery &&
        other.serviceId == serviceId &&
        other.providerId == providerId &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(serviceId, providerId, from, to);
}

final slotsProvider = FutureProvider.family<List<TimeSlot>, SlotQuery>((
  ref,
  query,
) {
  return ref
      .watch(schedulingRepositoryProvider)
      .slotsFor(
        serviceId: query.serviceId,
        providerId: query.providerId,
        rangeStart: query.from,
        rangeEnd: query.to,
      );
});

final appointmentByIdProvider = FutureProvider.family<Appointment?, String>((
  ref,
  id,
) {
  return ref.watch(schedulingRepositoryProvider).findAppointment(id);
});

final class MenuQuery {
  const MenuQuery({required this.serviceId, required this.providerId});

  final String serviceId;
  final String providerId;

  @override
  bool operator ==(Object other) {
    return other is MenuQuery &&
        other.serviceId == serviceId &&
        other.providerId == providerId;
  }

  @override
  int get hashCode => Object.hash(serviceId, providerId);
}

final menuProvider = FutureProvider.family<List<MenuItem>, MenuQuery>((
  ref,
  query,
) async {
  return ref
      .watch(orderingRepositoryProvider)
      .itemsFor(serviceId: query.serviceId, providerId: query.providerId);
});

final profileProvider = FutureProvider<CustomerProfile>((ref) async {
  final accountId = ref.watch(sessionProvider)?.id;
  if (accountId == null) {
    return CustomerProfile.empty('');
  }
  return ref.watch(profileRepositoryProvider).find(accountId);
});

final myActivityProvider = FutureProvider<MyActivity>((ref) async {
  final account = ref.watch(sessionProvider);
  if (account == null) {
    return const MyActivity(appointments: [], orders: []);
  }
  return ref.watch(loadMyActivityProvider).call(account.id);
});

final providerBookingsProvider = FutureProvider<List<ProviderBooking>>((
  ref,
) async {
  final providerId = ref.watch(sessionProvider)?.providerId;
  if (providerId == null) {
    return const [];
  }
  return ref.watch(loadProviderBookingsProvider).call(providerId);
});

final providerOfferingNamesProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final providerId = ref.watch(sessionProvider)?.providerId;
  if (providerId == null) {
    return const {};
  }
  final provider = await ref
      .watch(catalogRepositoryProvider)
      .findProvider(providerId);
  if (provider == null) {
    return const {};
  }
  final offerings = ref.watch(offeringRepositoryProvider);
  final names = <String, String>{};
  for (final serviceId in provider.serviceIds) {
    final offering = await offerings.find(
      providerId: providerId,
      serviceId: serviceId,
    );
    final name = offering?.name.trim() ?? '';
    if (name.isNotEmpty) {
      names[serviceId] = name;
    }
  }
  return names;
});

final providerServicesProvider = FutureProvider<List<CommunityService>>((
  ref,
) async {
  final providerId = ref.watch(sessionProvider)?.providerId;
  if (providerId == null) {
    return const [];
  }
  final provider = await ref
      .watch(catalogRepositoryProvider)
      .findProvider(providerId);
  if (provider == null) {
    return const [];
  }
  final services = await ref.watch(catalogRepositoryProvider).listServices();
  return services
      .where((service) => provider.serviceIds.contains(service.id))
      .toList();
});

final class WashQuery {
  const WashQuery({required this.providerId, required this.serviceId});

  final String providerId;
  final String serviceId;

  @override
  bool operator ==(Object other) {
    return other is WashQuery &&
        other.providerId == providerId &&
        other.serviceId == serviceId;
  }

  @override
  int get hashCode => Object.hash(providerId, serviceId);
}

final class OfferingQuery {
  const OfferingQuery({required this.providerId, required this.serviceId});

  final String providerId;
  final String serviceId;

  @override
  bool operator ==(Object other) {
    return other is OfferingQuery &&
        other.providerId == providerId &&
        other.serviceId == serviceId;
  }

  @override
  int get hashCode => Object.hash(providerId, serviceId);
}

final offeringProvider = FutureProvider.family<ServiceOffering?, OfferingQuery>(
  (ref, query) {
    return ref
        .watch(offeringRepositoryProvider)
        .find(providerId: query.providerId, serviceId: query.serviceId);
  },
);

final offeringsForServiceProvider =
    FutureProvider.family<List<ServiceOffering>, String>((ref, serviceId) {
      return ref.watch(offeringRepositoryProvider).forService(serviceId);
    });

final treatmentsProvider =
    FutureProvider.family<List<Treatment>, OfferingQuery>((ref, query) {
      return ref
          .watch(offeringRepositoryProvider)
          .treatmentsFor(
            providerId: query.providerId,
            serviceId: query.serviceId,
          );
    });

final washesProvider = FutureProvider.family<List<WashOption>, WashQuery>((
  ref,
  query,
) {
  return ref
      .watch(washRepositoryProvider)
      .washesFor(providerId: query.providerId, serviceId: query.serviceId);
});

final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final accountId = ref.watch(sessionProvider)?.id;
  if (accountId == null) {
    return const [];
  }
  return ref.watch(notificationRepositoryProvider).listFor(accountId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notices = ref.watch(notificationsProvider).asData?.value ?? const [];
  return notices.where((notice) => !notice.read).length;
});

void invalidateBookingViews(WidgetRef ref) {
  ref.invalidate(myActivityProvider);
  ref.invalidate(slotsProvider);
  ref.invalidate(providerBookingsProvider);
  ref.invalidate(appointmentByIdProvider);
  ref.invalidate(notificationsProvider);
}

void invalidateOfferViews(WidgetRef ref) {
  ref.invalidate(catalogServicesProvider);
  ref.invalidate(servicesProvider);
  ref.invalidate(allProvidersProvider);
  ref.invalidate(providerByIdProvider);
  ref.invalidate(providerServicesProvider);
  ref.invalidate(providersForServiceProvider);
  ref.invalidate(offeringProvider);
  ref.invalidate(offeringsForServiceProvider);
  ref.invalidate(providerOfferingNamesProvider);
  ref.invalidate(treatmentsProvider);
  ref.invalidate(menuProvider);
  ref.invalidate(slotsProvider);
}
