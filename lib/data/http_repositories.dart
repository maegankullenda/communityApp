import 'package:community_app/core/result.dart';
import 'package:community_app/data/api/api_json.dart';
import 'package:community_app/data/api/community_api.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/notifications/domain/notification_repository.dart';
import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

final class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);

  final CommunityApi _api;
  Account? _account;

  @override
  Account? get currentAccount => _account;

  @override
  Future<Account?> findById(String id) async {
    final json = await _api.getObject('/accounts/$id');
    return json == null ? null : accountFromJson(json);
  }

  @override
  Future<Account?> findByProviderId(String providerId) async {
    final json = await _api.getObject('/providers/$providerId/account');
    return json == null ? null : accountFromJson(json);
  }

  @override
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final json = await _api.postObject('/session', {
        'email': email,
        'password': password,
      });
      _api.token = json['token'] as String;
      _account = accountFromJson(
        Map<String, dynamic>.from(json['account'] as Map),
      );
      return Success(_account!);
    } on ApiException catch (error) {
      if (error.status == 401) {
        return const Err(AuthFailure.invalidCredentials);
      }
      if (error.code == 'unavailable') {
        return const Err(AuthFailure.unavailable);
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_api.token != null) {
        await _api.delete('/session');
      }
    } on ApiException {
      // Signing out still clears the phone session when the API is down.
    } finally {
      _api.token = null;
      _account = null;
    }
  }
}

final class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api);

  final CommunityApi _api;

  @override
  Future<List<CommunityService>> listServices() async {
    final rows = await _api.getList('/services');
    return [
      for (final row in rows)
        serviceFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<CommunityService?> findService(String id) async {
    final json = await _api.getObject('/services/$id');
    return json == null ? null : serviceFromJson(json);
  }

  @override
  Future<List<ServiceProvider>> providersFor(String serviceId) async {
    final rows = await _api.getList('/services/$serviceId/providers');
    return [
      for (final row in rows)
        providerFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<List<ServiceProvider>> listProviders() async {
    final rows = await _api.getList('/providers');
    return [
      for (final row in rows)
        providerFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<ServiceProvider?> findProvider(String id) async {
    final json = await _api.getObject('/providers/$id');
    return json == null ? null : providerFromJson(json);
  }

  @override
  Future<void> saveService(CommunityService service) {
    return _api.putObject('/services/${service.id}', serviceToJson(service));
  }

  @override
  Future<void> saveProvider(ServiceProvider provider) {
    return _api.putObject(
      '/providers/${provider.id}',
      providerToJson(provider),
    );
  }
}

final class HttpSchedulingRepository implements SchedulingRepository {
  HttpSchedulingRepository(this._api);

  final CommunityApi _api;

  @override
  Future<TimeSlot?> findSlot(String id) async {
    final json = await _api.getObject('/slots/$id');
    return json == null ? null : slotFromJson(json);
  }

  @override
  Future<List<TimeSlot>> slotsFor({
    required String serviceId,
    String? providerId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final rows = await _api.getList(
      '/slots',
      query: {
        'serviceId': serviceId,
        'providerId': ?providerId,
        'from': wallClockIso(rangeStart),
        'to': wallClockIso(rangeEnd),
      },
    );
    return [
      for (final row in rows)
        slotFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<Appointment?> activeAppointmentFor({
    required String userId,
    required String slotId,
  }) async {
    final json = await _api.getObject(
      '/appointments/active',
      query: {'userId': userId, 'slotId': slotId},
    );
    return json == null ? null : appointmentFromJson(json);
  }

  @override
  Future<Appointment?> findAppointment(String id) async {
    final json = await _api.getObject('/appointments/$id');
    return json == null ? null : appointmentFromJson(json);
  }

  @override
  Future<Result<Appointment, BookingFailure>> tryReserve({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    Duration? duration,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
    AppointmentStatus status = AppointmentStatus.booked,
  }) async {
    try {
      final json = await _api.postObject('/reservations', {
        'appointmentId': appointmentId,
        'userId': userId,
        'slotId': slotId,
        'vehicleLabel': vehicleLabel,
        'priceCents': priceCents,
        'vehicleIds': vehicleIds,
        'durationMinutes': duration?.inMinutes,
        'washId': washId,
        'washName': washName,
        'vehicleWashes': vehicleWashes,
        'status': status.name,
      });
      return Success(appointmentFromJson(json));
    } on ApiException catch (error) {
      if (error.status == 409) {
        return Err(_bookingFailure(error.code));
      }
      rethrow;
    }
  }

  @override
  Future<Result<Appointment, BookingFailure>> confirmAppointment({
    required String appointmentId,
    required String providerId,
  }) async {
    try {
      final json = await _api.postObject(
        '/appointments/$appointmentId/confirm',
        {'providerId': providerId},
      );
      return Success(appointmentFromJson(json));
    } on ApiException catch (error) {
      if (error.status == 409) {
        return Err(_bookingFailure(error.code));
      }
      rethrow;
    }
  }

  @override
  Future<Result<Appointment, BookingFailure>> declineAppointment({
    required String appointmentId,
    required String providerId,
    required String message,
    DateTime? suggestedFrom,
    DateTime? suggestedUntil,
  }) async {
    try {
      final json = await _api
          .postObject('/appointments/$appointmentId/decline', {
            'providerId': providerId,
            'message': message,
            'suggestedFrom': suggestedFrom == null
                ? null
                : _isoDate(suggestedFrom),
            'suggestedUntil': suggestedUntil == null
                ? null
                : _isoDate(suggestedUntil),
          });
      return Success(appointmentFromJson(json));
    } on ApiException catch (error) {
      if (error.status == 409) {
        return Err(_bookingFailure(error.code));
      }
      rethrow;
    }
  }

  @override
  Future<Result<Appointment, BookingFailure>> reschedule({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    Duration? duration,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
    AppointmentStatus? status,
  }) async {
    try {
      final json = await _api
          .postObject('/appointments/$appointmentId/reschedule', {
            'userId': userId,
            'slotId': slotId,
            'vehicleLabel': vehicleLabel,
            'priceCents': priceCents,
            'vehicleIds': vehicleIds,
            'durationMinutes': duration?.inMinutes,
            'washId': washId,
            'washName': washName,
            'vehicleWashes': vehicleWashes,
          });
      return Success(appointmentFromJson(json));
    } on ApiException catch (error) {
      if (error.status == 409) {
        return Err(_bookingFailure(error.code));
      }
      rethrow;
    }
  }

  @override
  Future<Result<Appointment, BookingFailure>> cancelAppointment({
    required String appointmentId,
    required String userId,
  }) async {
    try {
      final json = await _api.postObject(
        '/appointments/$appointmentId/cancel',
        {'userId': userId},
      );
      return Success(appointmentFromJson(json));
    } on ApiException catch (error) {
      if (error.status == 409) {
        return Err(_bookingFailure(error.code));
      }
      rethrow;
    }
  }

  @override
  Future<List<Appointment>> appointmentsForUser(String userId) async {
    final rows = await _api.getList('/users/$userId/appointments');
    return [
      for (final row in rows)
        appointmentFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<List<Appointment>> appointmentsForProvider(String providerId) async {
    final rows = await _api.getList('/providers/$providerId/appointments');
    return [
      for (final row in rows)
        appointmentFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> publishSlot(TimeSlot slot) {
    return _api.postEmpty('/slots', slotToJson(slot));
  }

  @override
  Future<void> removeSlot(String id) {
    return _api.delete('/slots/$id');
  }
}

final class HttpOrderingRepository implements OrderingRepository {
  HttpOrderingRepository(this._api);

  final CommunityApi _api;

  @override
  Future<MenuItem?> findItem(String id) async {
    final json = await _api.getObject('/menu-items/$id');
    return json == null ? null : menuItemFromJson(json);
  }

  @override
  Future<List<MenuItem>> itemsFor({
    required String serviceId,
    required String providerId,
  }) async {
    final rows = await _api.getList(
      '/menu-items',
      query: {'serviceId': serviceId, 'providerId': providerId},
    );
    return [
      for (final row in rows)
        menuItemFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> publishItem(MenuItem item) {
    return _api.postEmpty('/menu-items', menuItemToJson(item));
  }

  @override
  Future<void> saveOrder(CustomerOrder order) {
    return _api.postEmpty('/orders', orderToJson(order));
  }

  @override
  Future<List<CustomerOrder>> ordersForUser(String userId) async {
    final rows = await _api.getList('/users/$userId/orders');
    return [
      for (final row in rows)
        orderFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }
}

final class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._api);

  final CommunityApi _api;

  @override
  Future<CustomerProfile> find(String accountId) async {
    final json = await _api.getObject('/profiles/$accountId');
    if (json == null) {
      return CustomerProfile.empty(accountId);
    }
    return profileFromJson(json);
  }

  @override
  Future<void> save(CustomerProfile profile) {
    return _api.putObject(
      '/profiles/${profile.accountId}',
      profileToJson(profile),
    );
  }
}

final class HttpWashRepository implements WashRepository {
  HttpWashRepository(this._api);

  final CommunityApi _api;

  @override
  Future<List<WashOption>> washesFor({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _api.getList(
      '/providers/$providerId/washes',
      query: {'serviceId': serviceId},
    );
    return [
      for (final row in rows)
        washFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> replaceWashes({
    required String providerId,
    required String serviceId,
    required List<WashOption> washes,
  }) {
    return _api.putObject('/providers/$providerId/washes', {
      'serviceId': serviceId,
      'washes': [for (final wash in washes) washToJson(wash)],
    });
  }
}

final class HttpOfferingRepository implements OfferingRepository {
  HttpOfferingRepository(this._api);

  final CommunityApi _api;

  @override
  Future<ServiceOffering?> find({
    required String providerId,
    required String serviceId,
  }) async {
    final json = await _api.getObject(
      '/providers/$providerId/offering',
      query: {'serviceId': serviceId},
    );
    return json == null ? null : offeringFromJson(json);
  }

  @override
  Future<List<ServiceOffering>> forService(String serviceId) async {
    final rows = await _api.getList('/services/$serviceId/offerings');
    return [
      for (final row in rows)
        offeringFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> save(ServiceOffering offering) {
    return _api.putObject(
      '/providers/${offering.providerId}/offering',
      offeringToJson(offering),
    );
  }

  @override
  Future<List<Treatment>> treatmentsFor({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _api.getList(
      '/providers/$providerId/treatments',
      query: {'serviceId': serviceId},
    );
    return [
      for (final row in rows)
        treatmentFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> replaceTreatments({
    required String providerId,
    required String serviceId,
    required List<Treatment> treatments,
  }) {
    return _api.putObject('/providers/$providerId/treatments', {
      'serviceId': serviceId,
      'treatments': [
        for (final treatment in treatments) treatmentToJson(treatment),
      ],
    });
  }
}

final class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository(this._api);

  final CommunityApi _api;

  @override
  Future<List<AppNotification>> listFor(String accountId) async {
    final rows = await _api.getList('/accounts/$accountId/notifications');
    return [
      for (final row in rows)
        notificationFromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> add(AppNotification notification) {
    return _api.postEmpty('/notifications', notificationToJson(notification));
  }

  @override
  Future<void> markAllRead(String accountId) {
    return _api.postEmpty('/accounts/$accountId/notifications/read', const {});
  }

  @override
  Future<void> removeRequested(String appointmentId) {
    return _api.postEmpty('/notifications/remove-requested', {
      'appointmentId': appointmentId,
    });
  }
}

BookingFailure _bookingFailure(String code) {
  return switch (code) {
    'slotNotFound' => BookingFailure.slotNotFound,
    'slotInThePast' => BookingFailure.slotInThePast,
    'outsideBookingWindow' => BookingFailure.outsideBookingWindow,
    'notOpen' => BookingFailure.notOpen,
    'slotFull' => BookingFailure.slotFull,
    'alreadyBooked' => BookingFailure.alreadyBooked,
    'serviceMismatch' => BookingFailure.serviceMismatch,
    'vehicleRequired' => BookingFailure.vehicleRequired,
    'unknownVehicle' => BookingFailure.unknownVehicle,
    'appointmentNotFound' => BookingFailure.appointmentNotFound,
    'washRequired' => BookingFailure.washRequired,
    'unknownWash' => BookingFailure.unknownWash,
    'serviceUnavailable' => BookingFailure.serviceUnavailable,
    'missingDeclineMessage' => BookingFailure.missingDeclineMessage,
    'invalidSuggestedRange' => BookingFailure.invalidSuggestedRange,
    _ => throw ApiException(status: 409, code: code),
  };
}

String _isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
