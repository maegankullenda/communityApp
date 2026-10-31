import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:community_api/community_database.dart';

const jsonHeaders = {'content-type': 'application/json'};

Handler buildApi(CommunityDatabase database) {
  return Pipeline()
      .addMiddleware(requireSession(database))
      .addHandler(buildRouter(database).call);
}

Middleware requireSession(CommunityDatabase database) {
  return (Handler inner) {
    return (Request request) async {
      if (_isPublic(request)) {
        return inner(request);
      }
      final header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        return _json({'error': 'unauthorized'}, status: 401);
      }
      final account = await database.accountForToken(header.substring(7));
      if (account == null) {
        return _json({'error': 'unauthorized'}, status: 401);
      }
      return inner(request);
    };
  };
}

Router buildRouter(CommunityDatabase database) {
  final router = Router();

  router.get('/health', (Request request) {
    return _json({'status': 'ok'});
  });

  router.post('/session', (Request request) async {
    final body = await _readJson(request);
    final session = await database.signIn(
      email: body['email'] as String? ?? '',
      password: body['password'] as String? ?? '',
    );
    if (session == null) {
      return _json({'error': 'invalidCredentials'}, status: 401);
    }
    return _json(session);
  });

  router.delete('/session', (Request request) async {
    final header = request.headers['authorization'] ?? '';
    await database.deleteSession(header.substring(7));
    return Response(204);
  });

  router.get('/accounts/<id>', (Request request, String id) async {
    final account = await database.findAccount(id);
    if (account == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(account);
  });

  router.get('/accounts/<id>/notifications', (
    Request request,
    String id,
  ) async {
    return _json(await database.notificationsFor(id));
  });

  router.post('/accounts/<id>/notifications/read', (
    Request request,
    String id,
  ) async {
    await database.markNotificationsRead(id);
    return Response(204);
  });

  router.post('/notifications', (Request request) async {
    await database.addNotification(await _readJson(request));
    return Response(204);
  });

  router.post('/notifications/remove-requested', (Request request) async {
    final body = await _readJson(request);
    await database.removeRequestedNotification(
      body['appointmentId'] as String? ?? '',
    );
    return Response(204);
  });

  router.get('/services', (Request request) async {
    return _json(await database.listServices());
  });

  router.get('/services/<id>', (Request request, String id) async {
    final service = await database.findService(id);
    if (service == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(service);
  });

  router.put('/services/<id>', (Request request, String id) async {
    final body = await _readJson(request);
    body['id'] = id;
    await database.saveService(body);
    return Response(204);
  });

  router.get('/services/<id>/providers', (Request request, String id) async {
    return _json(await database.providersFor(id));
  });

  router.get('/providers', (Request request) async {
    return _json(await database.listProviders());
  });

  router.get('/providers/<id>/account', (Request request, String id) async {
    final account = await database.accountForProvider(id);
    if (account == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(account);
  });

  router.get('/providers/<id>', (Request request, String id) async {
    final provider = await database.findProvider(id);
    if (provider == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(provider);
  });

  router.put('/providers/<id>', (Request request, String id) async {
    final body = await _readJson(request);
    body['id'] = id;
    await database.saveProvider(body);
    return Response(204);
  });

  router.get('/slots/<id>', (Request request, String id) async {
    final slot = await database.findSlot(id);
    if (slot == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(slot);
  });

  router.get('/slots', (Request request) async {
    final query = request.url.queryParameters;
    return _json(
      await database.slotsFor(
        serviceId: query['serviceId'] ?? '',
        providerId: query['providerId'],
        rangeStart: query['from'] ?? '',
        rangeEnd: query['to'] ?? '',
      ),
    );
  });

  router.post('/slots', (Request request) async {
    await database.publishSlot(await _readJson(request));
    return Response(204);
  });

  router.delete('/slots/<id>', (Request request, String id) async {
    await database.removeSlot(id);
    return Response(204);
  });

  router.get('/appointments/active', (Request request) async {
    final query = request.url.queryParameters;
    final appointment = await database.activeAppointmentFor(
      userId: query['userId'] ?? '',
      slotId: query['slotId'] ?? '',
    );
    if (appointment == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(appointment);
  });

  router.post('/reservations', (Request request) async {
    final body = await _readJson(request);
    final reservation = await database.tryReserve(
      appointmentId: body['appointmentId'] as String,
      userId: body['userId'] as String,
      slotId: body['slotId'] as String,
      vehicleLabel: body['vehicleLabel'] as String?,
      priceCents: body['priceCents'] == null ? null : asInt(body['priceCents']),
      vehicleIds: [
        for (final vehicleId
            in (body['vehicleIds'] as List<dynamic>?) ?? const [])
          vehicleId as String,
      ],
      durationMinutes: body['durationMinutes'] == null
          ? null
          : asInt(body['durationMinutes']),
      washId: body['washId'] as String?,
      washName: body['washName'] as String?,
      vehicleWashes: _vehicleWashes(body['vehicleWashes']),
    );
    if (reservation.failure != null) {
      return _json({'error': reservation.failure}, status: 409);
    }
    return _json(reservation.appointment);
  });

  router.get('/appointments/<id>', (Request request, String id) async {
    final appointment = await database.findAppointment(id);
    if (appointment == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(appointment);
  });

  router.post('/appointments/<id>/reschedule', (
    Request request,
    String id,
  ) async {
    final body = await _readJson(request);
    final reservation = await database.reschedule(
      appointmentId: id,
      userId: body['userId'] as String,
      slotId: body['slotId'] as String,
      vehicleLabel: body['vehicleLabel'] as String?,
      priceCents: body['priceCents'] == null ? null : asInt(body['priceCents']),
      vehicleIds: [
        for (final vehicleId
            in (body['vehicleIds'] as List<dynamic>?) ?? const [])
          vehicleId as String,
      ],
      durationMinutes: body['durationMinutes'] == null
          ? null
          : asInt(body['durationMinutes']),
      washId: body['washId'] as String?,
      washName: body['washName'] as String?,
      vehicleWashes: _vehicleWashes(body['vehicleWashes']),
    );
    if (reservation.failure != null) {
      return _json({'error': reservation.failure}, status: 409);
    }
    return _json(reservation.appointment);
  });

  router.post('/appointments/<id>/confirm', (Request request, String id) async {
    final body = await _readJson(request);
    final reservation = await database.confirmAppointment(
      appointmentId: id,
      providerId: body['providerId'] as String,
    );
    if (reservation.failure != null) {
      return _json({'error': reservation.failure}, status: 409);
    }
    return _json(reservation.appointment);
  });

  router.post('/appointments/<id>/decline', (Request request, String id) async {
    final body = await _readJson(request);
    final reservation = await database.declineAppointment(
      appointmentId: id,
      providerId: body['providerId'] as String,
      message: body['message'] as String? ?? '',
      suggestedFrom: body['suggestedFrom'] as String? ?? '',
      suggestedUntil: body['suggestedUntil'] as String? ?? '',
    );
    if (reservation.failure != null) {
      return _json({'error': reservation.failure}, status: 409);
    }
    return _json(reservation.appointment);
  });

  router.post('/appointments/<id>/cancel', (Request request, String id) async {
    final body = await _readJson(request);
    final reservation = await database.cancelAppointment(
      appointmentId: id,
      userId: body['userId'] as String,
    );
    if (reservation.failure != null) {
      return _json({'error': reservation.failure}, status: 409);
    }
    return _json(reservation.appointment);
  });

  router.get('/users/<userId>/appointments', (
    Request request,
    String userId,
  ) async {
    return _json(await database.appointmentsForUser(userId));
  });

  router.get('/providers/<providerId>/appointments', (
    Request request,
    String providerId,
  ) async {
    return _json(await database.appointmentsForProvider(providerId));
  });

  router.get('/menu-items/<id>', (Request request, String id) async {
    final item = await database.findItem(id);
    if (item == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(item);
  });

  router.get('/menu-items', (Request request) async {
    final query = request.url.queryParameters;
    return _json(
      await database.itemsFor(
        serviceId: query['serviceId'] ?? '',
        providerId: query['providerId'] ?? '',
      ),
    );
  });

  router.post('/menu-items', (Request request) async {
    await database.publishItem(await _readJson(request));
    return Response(204);
  });

  router.post('/orders', (Request request) async {
    await database.saveOrder(await _readJson(request));
    return Response(204);
  });

  router.get('/users/<userId>/orders', (Request request, String userId) async {
    return _json(await database.ordersForUser(userId));
  });

  router.get('/services/<id>/offerings', (Request request, String id) async {
    return _json(await database.offeringsFor(id));
  });

  router.get('/providers/<providerId>/offering', (
    Request request,
    String providerId,
  ) async {
    final serviceId = request.url.queryParameters['serviceId'];
    if (serviceId == null || serviceId.isEmpty) {
      return _json({'error': 'serviceRequired'}, status: 400);
    }
    final offering = await database.findOffering(
      providerId: providerId,
      serviceId: serviceId,
    );
    if (offering == null) {
      return _json({'error': 'notFound'}, status: 404);
    }
    return _json(offering);
  });

  router.put('/providers/<providerId>/offering', (
    Request request,
    String providerId,
  ) async {
    final body = await _readJson(request);
    body['providerId'] = providerId;
    await database.saveOffering(body);
    return Response(204);
  });

  router.get('/providers/<providerId>/treatments', (
    Request request,
    String providerId,
  ) async {
    final serviceId = request.url.queryParameters['serviceId'];
    if (serviceId == null || serviceId.isEmpty) {
      return _json({'error': 'serviceRequired'}, status: 400);
    }
    return _json(
      await database.treatmentsFor(
        providerId: providerId,
        serviceId: serviceId,
      ),
    );
  });

  router.put('/providers/<providerId>/treatments', (
    Request request,
    String providerId,
  ) async {
    final body = await _readJson(request);
    final serviceId = body['serviceId'] as String;
    await database.replaceTreatments(
      providerId: providerId,
      serviceId: serviceId,
      treatments: [
        for (final treatment in body['treatments'] as List<dynamic>)
          Map<String, dynamic>.from(treatment as Map),
      ],
    );
    return Response(204);
  });

  router.get('/providers/<providerId>/washes', (
    Request request,
    String providerId,
  ) async {
    final serviceId = request.url.queryParameters['serviceId'];
    if (serviceId == null || serviceId.isEmpty) {
      return _json({'error': 'serviceRequired'}, status: 400);
    }
    return _json(
      await database.washesFor(providerId: providerId, serviceId: serviceId),
    );
  });

  router.put('/providers/<providerId>/washes', (
    Request request,
    String providerId,
  ) async {
    final body = await _readJson(request);
    final serviceId = body['serviceId'] as String;
    await database.replaceWashes(
      providerId: providerId,
      serviceId: serviceId,
      washes: [
        for (final wash in body['washes'] as List<dynamic>)
          Map<String, dynamic>.from(wash as Map),
      ],
    );
    return Response(204);
  });

  router.get('/profiles/<accountId>', (
    Request request,
    String accountId,
  ) async {
    return _json(await database.findProfile(accountId));
  });

  router.put('/profiles/<accountId>', (
    Request request,
    String accountId,
  ) async {
    final body = await _readJson(request);
    body['accountId'] = accountId;
    await database.saveProfile(body);
    return Response(204);
  });

  return router;
}

bool _isPublic(Request request) {
  final path = _routePath(request);
  if (path == 'health') {
    return true;
  }
  return request.method == 'POST' && path == 'session';
}

String _routePath(Request request) {
  final path = request.url.path;
  return path.startsWith('/') ? path.substring(1) : path;
}

Map<String, String> _vehicleWashes(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  final decoded = jsonDecode(await request.readAsString());
  return Map<String, dynamic>.from(decoded as Map);
}

Response _json(Object? body, {int status = 200}) {
  return Response(status, body: jsonEncode(body), headers: jsonHeaders);
}
