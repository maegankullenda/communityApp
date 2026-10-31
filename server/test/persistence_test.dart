import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:community_api/community_database.dart';
import 'package:community_api/http_api.dart';

void main() {
  late CommunityDatabase database;
  late Handler api;

  setUpAll(() async {
    await _ensureTestDatabase();
    database = await CommunityDatabase.open(
      host: 'localhost',
      port: 5432,
      database: 'community_test',
      username: 'community',
      password: 'community',
    );
    await database.resetSchema();
    await database.seedIfEmpty(now: DateTime(2026, 10, 5, 8));
    await database.seedIfEmpty(now: DateTime(2026, 10, 8, 8));
    api = buildApi(database);
  });

  tearDownAll(() async {
    await database.close();
  });

  test('a profile and a car wash survive a new database connection', () async {
    final denied = await _request(
      api,
      method: 'POST',
      path: '/session',
      body: {'email': 'alex@community.app', 'password': 'wrong'},
    );
    expect(denied.statusCode, 401);

    final signedIn = await _request(
      api,
      method: 'POST',
      path: '/session',
      body: {'email': ' Alex@Community.app ', 'password': 'community'},
    );
    expect(signedIn.statusCode, 200);
    final session = jsonDecode(signedIn.body) as Map<String, dynamic>;
    final token = session['token'] as String;
    expect(session['account']['displayName'], 'Alex');

    final saved = await _request(
      api,
      method: 'PUT',
      path: '/profiles/alex',
      token: token,
      body: {
        'firstName': 'Alex',
        'surname': 'Nkosi',
        'address': '14 Oak Street',
        'contactNumber': '0821234567',
        'vehicles': [
          {
            'id': 'vehicle-1',
            'name': 'City run',
            'type': 'hatch',
            'registration': 'CA 123-456',
          },
        ],
      },
    );
    expect(saved.statusCode, 204);

    const slotId = 'car-wash-sam-shine-20261006-0900';
    final booked = await _request(
      api,
      method: 'POST',
      path: '/reservations',
      token: token,
      body: {
        'appointmentId': 'appointment-1',
        'userId': 'alex',
        'slotId': slotId,
        'vehicleLabel': 'City run (Hatch)',
        'priceCents': 12000,
      },
    );
    expect(booked.statusCode, 200);
    final appointment = jsonDecode(booked.body) as Map<String, dynamic>;
    expect(appointment['start'], '2026-10-06T09:00:00.000');
    expect(appointment['priceCents'], 12000);

    final full = await _request(
      api,
      method: 'POST',
      path: '/reservations',
      token: token,
      body: {
        'appointmentId': 'appointment-2',
        'userId': 'sam',
        'slotId': slotId,
      },
    );
    expect(full.statusCode, 409);
    expect(jsonDecode(full.body)['error'], 'slotFull');

    final reopened = await CommunityDatabase.open(
      host: 'localhost',
      port: 5432,
      database: 'community_test',
      username: 'community',
      password: 'community',
    );
    addTearDown(reopened.close);

    final profile = await reopened.findProfile('alex');
    expect(profile['firstName'], 'Alex');
    expect(profile['surname'], 'Nkosi');
    expect(profile['address'], '14 Oak Street');
    expect(profile['vehicles'], [
      {
        'id': 'vehicle-1',
        'name': 'City run',
        'type': 'hatch',
        'registration': 'CA 123-456',
      },
    ]);
    final appointments = await reopened.appointmentsForUser('alex');
    expect(appointments, hasLength(1));
    expect(appointments.single['vehicleLabel'], 'City run (Hatch)');
    expect(appointments.single['priceCents'], 12000);
    final slot = await reopened.findSlot(slotId);
    expect(slot!['bookedCount'], 1);

    final services = await reopened.listServices();
    expect(services.map((service) => service['id']), [
      'car-wash',
      'foodie',
      'beauty',
    ]);
  });

  test('rescheduling and cancelling a wash updates the stored times', () async {
    final signedIn = await _request(
      api,
      method: 'POST',
      path: '/session',
      body: {'email': 'alex@community.app', 'password': 'community'},
    );
    final token =
        (jsonDecode(signedIn.body) as Map<String, dynamic>)['token'] as String;
    const original = 'car-wash-sam-shine-20261006-1100';
    const moved = 'car-wash-sam-shine-20261006-1300';

    final booked = await _request(
      api,
      method: 'POST',
      path: '/reservations',
      token: token,
      body: {
        'appointmentId': 'appointment-move',
        'userId': 'alex',
        'slotId': original,
        'vehicleLabel': 'City run (Hatch)',
        'priceCents': 12000,
        'vehicleIds': ['vehicle-1'],
      },
    );
    expect(booked.statusCode, 200);

    final changed = await _request(
      api,
      method: 'POST',
      path: '/appointments/appointment-move/reschedule',
      token: token,
      body: {
        'userId': 'alex',
        'slotId': moved,
        'vehicleLabel': 'Weekend (SUV)',
        'priceCents': 22000,
        'vehicleIds': ['vehicle-2'],
      },
    );
    expect(changed.statusCode, 200);
    final appointment = jsonDecode(changed.body) as Map<String, dynamic>;
    expect(appointment['start'], '2026-10-06T13:00:00.000');
    expect(appointment['vehicleIds'], ['vehicle-2']);
    expect((await database.findSlot(original))!['bookedCount'], 0);
    expect((await database.findSlot(moved))!['bookedCount'], 1);

    final cancelled = await _request(
      api,
      method: 'POST',
      path: '/appointments/appointment-move/cancel',
      token: token,
      body: {'userId': 'alex'},
    );
    expect(cancelled.statusCode, 200);
    expect(jsonDecode(cancelled.body)['status'], 'cancelled');
    expect((await database.findSlot(moved))!['bookedCount'], 0);

    final reopened = await CommunityDatabase.open(
      host: 'localhost',
      port: 5432,
      database: 'community_test',
      username: 'community',
      password: 'community',
    );
    addTearDown(reopened.close);
    final stored = await reopened.findAppointment('appointment-move');
    expect(stored!['status'], 'cancelled');
    expect((await reopened.findSlot(moved))!['bookedCount'], 0);
  });
}

Future<void> _ensureTestDatabase() async {
  final admin = await CommunityDatabase.open(
    host: 'localhost',
    port: 5432,
    database: 'community',
    username: 'community',
    password: 'community',
  );
  try {
    await admin.applySchema();
  } finally {
    await admin.close();
  }

  final maintenance = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'community',
      username: 'community',
      password: 'community',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
  try {
    final existing = await maintenance.execute(
      "SELECT 1 FROM pg_database WHERE datname = 'community_test'",
    );
    if (existing.isEmpty) {
      await maintenance.execute('CREATE DATABASE community_test');
    }
  } finally {
    await maintenance.close();
  }
}

Future<_ApiResult> _request(
  Handler api, {
  required String method,
  required String path,
  String? token,
  Map<String, dynamic>? body,
}) async {
  final request = Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body == null ? null : jsonEncode(body),
    headers: {
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    },
  );
  final response = await api(request);
  return _ApiResult(response.statusCode, await response.readAsString());
}

final class _ApiResult {
  const _ApiResult(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
