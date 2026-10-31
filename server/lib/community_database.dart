import 'dart:io';
import 'dart:math';

import 'package:postgres/postgres.dart';

import 'package:community_api/passwords.dart';
import 'package:community_api/schema.dart';
import 'package:community_api/wall_clock.dart';

const demoPassword = 'community';

final class Reservation {
  const Reservation.booked(this.appointment) : failure = null;

  const Reservation.rejected(this.failure) : appointment = null;

  final Map<String, dynamic>? appointment;
  final String? failure;
}

final class CommunityDatabase {
  CommunityDatabase(this._connection);

  final Connection _connection;

  static Future<CommunityDatabase> connectFromEnvironment() async {
    final host = Platform.environment['PGHOST'] ?? 'localhost';
    final port = int.parse(Platform.environment['PGPORT'] ?? '5432');
    final database = Platform.environment['PGDATABASE'] ?? 'community';
    final username = Platform.environment['PGUSER'] ?? 'community';
    final password = Platform.environment['PGPASSWORD'] ?? 'community';
    return open(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }

  static Future<CommunityDatabase> open({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        final connection = await Connection.open(
          Endpoint(
            host: host,
            port: port,
            database: database,
            username: username,
            password: password,
          ),
          settings: ConnectionSettings(sslMode: SslMode.disable),
        );
        return CommunityDatabase(connection);
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw StateError('Could not reach Postgres: $lastError');
  }

  Future<void> close() => _connection.close();

  Future<void> applySchema() async {
    for (final statement in schemaStatements) {
      await _connection.execute(statement);
    }
  }

  Future<void> resetSchema() async {
    await _connection.execute('DROP SCHEMA public CASCADE');
    await _connection.execute('CREATE SCHEMA public');
    await applySchema();
  }

  Future<void> seedIfEmpty({DateTime? now}) async {
    final count = await _one(
      'SELECT COUNT(*) AS count FROM accounts',
      const {},
    );
    if (count != null && asInt(count['count']) > 0) {
      return;
    }
    await _seed(now ?? DateTime.now());
  }

  /// Adds any missing bookable times for the next week without touching
  /// times that are already reserved.
  Future<void> ensureUpcomingOpenings({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day);
    final rows = await _connection.execute('''
      SELECT ps.provider_id, s.id AS service_id
      FROM provider_services ps
      JOIN services s ON s.id = ps.service_id
      WHERE s.fulfillment = 'appointment' AND ps.active
      ''');
    for (final row in rows) {
      final map = row.toColumnMap();
      final providerId = map['provider_id'] as String;
      final serviceId = map['service_id'] as String;
      final schedule = await _scheduleForOffering(
        providerId: providerId,
        serviceId: serviceId,
      );
      for (final day in _bookingDays(today, schedule)) {
        if (schedule.weekdays.isNotEmpty &&
            !schedule.weekdays.contains(day.weekday)) {
          continue;
        }
        final hours = _hoursOn(schedule, day.weekday);
        for (final hour in hours) {
          final start = DateTime(day.year, day.month, day.day, hour);
          if (!_withinBookingWindow(start, today, schedule)) {
            continue;
          }
          await _connection.execute(
            Sql.named('''
              INSERT INTO time_slots (
                id, provider_id, service_id, starts_at, duration_minutes,
                capacity, booked_count
              )
              SELECT @id, @providerId, @serviceId, @startsAt, 60, 1, 0
              WHERE NOT EXISTS (
                SELECT 1 FROM time_slots
                WHERE provider_id = @providerId
                  AND service_id = @serviceId
                  AND starts_at = @startsAt
              )
              ON CONFLICT (id) DO NOTHING
              '''),
            parameters: {
              'id': _slotId(
                serviceId: serviceId,
                providerId: providerId,
                start: start,
              ),
              'providerId': providerId,
              'serviceId': serviceId,
              'startsAt': wallClockIso(start),
            },
          );
        }
      }
      await _dropClosedOpenings(
        providerId: providerId,
        serviceId: serviceId,
        startDay: startDay,
        now: today,
        schedule: schedule,
      );
    }
  }

  Future<void> _dropClosedOpenings({
    required String providerId,
    required String serviceId,
    required DateTime startDay,
    required DateTime now,
    required _OpeningSchedule schedule,
  }) async {
    final existing = await slotsFor(
      serviceId: serviceId,
      providerId: providerId,
      rangeStart: wallClockIso(startDay),
      rangeEnd: wallClockIso(startDay.add(const Duration(days: 370))),
    );
    for (final slot in existing) {
      final start = DateTime.parse(slot['start'] as String);
      final open =
          schedule.weekdays.isEmpty ||
          schedule.weekdays.contains(start.weekday);
      final hours = _hoursOn(schedule, start.weekday);
      if (!open ||
          !hours.contains(start.hour) ||
          !_withinBookingWindow(start, now, schedule)) {
        await removeSlot(slot['id'] as String);
      }
    }
  }

  Future<_OpeningSchedule> _scheduleForOffering({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT open_hours, open_weekdays, weekday_hours, weekend_hours,
               advance_amount, advance_unit, open_for_amount, open_for_unit
        FROM offerings
        WHERE provider_id = @providerId AND service_id = @serviceId
        '''),
      parameters: {'providerId': providerId, 'serviceId': serviceId},
    );
    if (rows.isEmpty) {
      return _OpeningSchedule(
        weekdayHours: const [],
        weekendHours: const [],
        sharedHours: _openingHours(serviceId),
        weekdays: const [],
        advanceAmount: 0,
        advanceUnit: 'hour',
        openForAmount: 1,
        openForUnit: 'week',
      );
    }
    final map = rows.first.toColumnMap();
    final shared = _decodeHours(map['open_hours']);
    return _OpeningSchedule(
      weekdayHours: _decodeHours(map['weekday_hours']),
      weekendHours: _decodeHours(map['weekend_hours']),
      sharedHours: shared.isEmpty ? _openingHours(serviceId) : shared,
      weekdays: _decodeHours(map['open_weekdays']),
      advanceAmount: asInt(map['advance_amount'] ?? 0),
      advanceUnit: map['advance_unit'] as String? ?? 'hour',
      openForAmount: asInt(map['open_for_amount'] ?? 1),
      openForUnit: map['open_for_unit'] as String? ?? 'week',
    );
  }

  Future<void> seedJordanAccount() async {
    final existing = await _one(
      'SELECT id FROM accounts WHERE id = @id',
      const {'id': 'jordan'},
    );
    if (existing != null) {
      return;
    }
    await _connection.execute(
      Sql.named('''
        INSERT INTO accounts (
          id, email, display_name, role, provider_id, password_hash
        ) VALUES (
          @id, @email, @displayName, @role, @providerId, @passwordHash
        )
        '''),
      parameters: {
        'id': 'jordan',
        'email': 'jordan@community.app',
        'displayName': 'Jordan',
        'role': 'customer',
        'providerId': null,
        'passwordHash': hashPassword(demoPassword),
      },
    );
  }

  Future<void> seedAdminAccount() async {
    final existing = await _one(
      'SELECT id FROM accounts WHERE id = @id',
      const {'id': 'maegan-admin'},
    );
    if (existing != null) {
      return;
    }
    await _connection.execute(
      Sql.named('''
        INSERT INTO accounts (
          id, email, display_name, role, provider_id, password_hash
        ) VALUES (
          @id, @email, @displayName, @role, @providerId, @passwordHash
        )
        '''),
      parameters: {
        'id': 'maegan-admin',
        'email': 'maeganadmin@community.app',
        'displayName': 'Maegan Admin',
        'role': 'admin',
        'providerId': null,
        'passwordHash': hashPassword(demoPassword),
      },
    );
  }

  Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final row = await _one(
      '''
      SELECT id, email, display_name, role, provider_id, password_hash
      FROM accounts
      WHERE email = @email
      ''',
      {'email': normalized},
    );
    if (row == null ||
        !verifyPassword(password, row['password_hash'] as String)) {
      return null;
    }
    final token = _newToken();
    await _connection.execute(
      Sql.named('''
        INSERT INTO sessions (token, account_id, created_at)
        VALUES (@token, @accountId, @createdAt)
        '''),
      parameters: {
        'token': token,
        'accountId': row['id'],
        'createdAt': wallClockIso(DateTime.now()),
      },
    );
    return {'token': token, 'account': _account(row)};
  }

  Future<void> deleteSession(String token) async {
    await _connection.execute(
      Sql.named('DELETE FROM sessions WHERE token = @token'),
      parameters: {'token': token},
    );
  }

  Future<Map<String, dynamic>?> accountForToken(String token) async {
    return _one(
      '''
      SELECT a.id, a.email, a.display_name, a.role, a.provider_id
      FROM sessions s
      JOIN accounts a ON a.id = s.account_id
      WHERE s.token = @token
      ''',
      {'token': token},
    ).then((row) => row == null ? null : _account(row));
  }

  Future<Map<String, dynamic>?> findAccount(String id) async {
    final row = await _one(
      '''
      SELECT id, email, display_name, role, provider_id
      FROM accounts
      WHERE id = @id
      ''',
      {'id': id},
    );
    return row == null ? null : _account(row);
  }

  Future<Map<String, dynamic>?> accountForProvider(String providerId) async {
    final row = await _one(
      '''
      SELECT id, email, display_name, role, provider_id
      FROM accounts
      WHERE provider_id = @providerId
      ''',
      {'providerId': providerId},
    );
    return row == null ? null : _account(row);
  }

  Future<List<Map<String, dynamic>>> notificationsFor(String accountId) async {
    await _connection.execute(
      Sql.named('''
        DELETE FROM notifications
        WHERE account_id = @accountId
          AND visible_until IS NOT NULL
          AND visible_until <= @now
        '''),
      parameters: {'accountId': accountId, 'now': wallClockIso(DateTime.now())},
    );
    final rows = await _connection.execute(
      Sql.named('''
        SELECT id, account_id, appointment_id, kind, message, created_at,
               visible_until, read
        FROM notifications
        WHERE account_id = @accountId
        ORDER BY created_at DESC, id DESC
        '''),
      parameters: {'accountId': accountId},
    );
    return [for (final row in rows) _notification(row.toColumnMap())];
  }

  Future<void> addNotification(Map<String, dynamic> notice) async {
    await _connection.execute(
      Sql.named('''
        INSERT INTO notifications (
          id, account_id, appointment_id, kind, message, created_at,
          visible_until, read
        ) VALUES (
          @id, @accountId, @appointmentId, @kind, @message, @createdAt,
          @visibleUntil, false
        )
        '''),
      parameters: {
        'id': notice['id'],
        'accountId': notice['accountId'],
        'appointmentId': notice['appointmentId'],
        'kind': notice['kind'],
        'message': notice['message'],
        'createdAt': notice['createdAt'],
        'visibleUntil': notice['visibleUntil'],
      },
    );
  }

  Future<void> removeRequestedNotification(String appointmentId) async {
    await _connection.execute(
      Sql.named('''
        DELETE FROM notifications
        WHERE appointment_id = @appointmentId AND kind = 'requested'
        '''),
      parameters: {'appointmentId': appointmentId},
    );
  }

  Future<void> markNotificationsRead(String accountId) async {
    await _connection.execute(
      Sql.named('''
        UPDATE notifications
        SET read = true
        WHERE account_id = @accountId AND read = false
        '''),
      parameters: {'accountId': accountId},
    );
  }

  Future<List<Map<String, dynamic>>> listServices() async {
    final rows = await _connection.execute(
      'SELECT id, name, summary, fulfillment, active FROM services ORDER BY position',
    );
    return [for (final row in rows) _service(row.toColumnMap())];
  }

  Future<Map<String, dynamic>?> findService(String id) async {
    final row = await _one(
      '''
      SELECT id, name, summary, fulfillment, active
      FROM services
      WHERE id = @id
      ''',
      {'id': id},
    );
    return row == null ? null : _service(row);
  }

  Future<void> saveService(Map<String, dynamic> service) async {
    final existing = await findService(service['id'] as String);
    if (existing == null) {
      final next = await _one(
        'SELECT COALESCE(MAX(position), 0) AS position FROM services',
        const {},
      );
      await _connection.execute(
        Sql.named('''
          INSERT INTO services (id, name, summary, fulfillment, position, active)
          VALUES (@id, @name, @summary, @fulfillment, @position, @active)
          '''),
        parameters: {
          'id': service['id'],
          'name': service['name'],
          'summary': service['summary'],
          'fulfillment': service['fulfillment'],
          'position': asInt(next!['position']) + 1,
          'active': service['active'] != false,
        },
      );
      return;
    }
    await _connection.execute(
      Sql.named('''
        UPDATE services
        SET name = @name, summary = @summary, fulfillment = @fulfillment,
            active = @active
        WHERE id = @id
        '''),
      parameters: {
        'id': service['id'],
        'name': service['name'],
        'summary': service['summary'],
        'fulfillment': service['fulfillment'],
        'active': service['active'] != false,
      },
    );
  }

  Future<Map<String, dynamic>?> findProvider(String id) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT p.id, p.display_name, p.bio, p.active AS provider_active,
               ps.service_id, ps.active
        FROM providers p
        LEFT JOIN provider_services ps ON ps.provider_id = p.id
        WHERE p.id = @id
        ORDER BY ps.service_id
        '''),
      parameters: {'id': id},
    );
    final grouped = _groupProviders(rows);
    return grouped.isEmpty ? null : grouped.single;
  }

  Future<List<Map<String, dynamic>>> providersFor(String serviceId) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT p.id, p.display_name, p.bio, p.active AS provider_active,
               link.service_id, link.active
        FROM providers p
        JOIN provider_services offered ON offered.provider_id = p.id
        LEFT JOIN provider_services link ON link.provider_id = p.id
        WHERE offered.service_id = @serviceId
          AND offered.active
          AND p.active
        ORDER BY p.display_name, link.service_id
        '''),
      parameters: {'serviceId': serviceId},
    );
    return _groupProviders(rows);
  }

  Future<List<Map<String, dynamic>>> listProviders() async {
    final rows = await _connection.execute('''
      SELECT p.id, p.display_name, p.bio, p.active AS provider_active,
             ps.service_id, ps.active
      FROM providers p
      LEFT JOIN provider_services ps ON ps.provider_id = p.id
      ORDER BY p.display_name, ps.service_id
      ''');
    return _groupProviders(rows);
  }

  Future<void> saveProvider(Map<String, dynamic> provider) async {
    final serviceIds = (provider['serviceIds'] as List).cast<String>();
    final inactive = {
      for (final id in (provider['inactiveServiceIds'] as List?) ?? const [])
        id as String,
    };
    await _connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO providers (id, display_name, bio, active)
          VALUES (@id, @displayName, @bio, @providerActive)
          ON CONFLICT (id) DO UPDATE
          SET display_name = EXCLUDED.display_name,
              bio = EXCLUDED.bio,
              active = EXCLUDED.active
          '''),
        parameters: {
          'id': provider['id'],
          'displayName': provider['displayName'],
          'bio': provider['bio'],
          'providerActive': provider['active'] != false,
        },
      );
      await tx.execute(
        Sql.named(
          'DELETE FROM provider_services WHERE provider_id = @providerId',
        ),
        parameters: {'providerId': provider['id']},
      );
      for (final serviceId in serviceIds) {
        await tx.execute(
          Sql.named('''
            INSERT INTO provider_services (provider_id, service_id, active)
            VALUES (@providerId, @serviceId, @active)
            '''),
          parameters: {
            'providerId': provider['id'],
            'serviceId': serviceId,
            'active': !inactive.contains(serviceId),
          },
        );
      }
      await tx.execute(
        Sql.named('''
          DELETE FROM time_slots t
          WHERE t.provider_id = @providerId
            AND NOT EXISTS (
              SELECT 1 FROM provider_services ps
              WHERE ps.provider_id = t.provider_id
                AND ps.service_id = t.service_id
            )
            AND NOT EXISTS (
              SELECT 1 FROM appointments a WHERE a.slot_id = t.id
            )
          '''),
        parameters: {'providerId': provider['id']},
      );
      await tx.execute(
        Sql.named('''
          DELETE FROM treatments
          WHERE provider_id = @providerId
            AND service_id NOT IN (
              SELECT service_id FROM provider_services
              WHERE provider_id = @providerId
            )
          '''),
        parameters: {'providerId': provider['id']},
      );
      await tx.execute(
        Sql.named('''
          DELETE FROM offerings
          WHERE provider_id = @providerId
            AND service_id NOT IN (
              SELECT service_id FROM provider_services
              WHERE provider_id = @providerId
            )
          '''),
        parameters: {'providerId': provider['id']},
      );
      await _deleteUnownedServices(tx);
    });
  }

  Future<void> deleteUnownedServices() {
    return _connection.runTx(_deleteUnownedServices);
  }

  Future<void> _deleteUnownedServices(Session session) async {
    const unowned = '''
      SELECT id FROM services s
      WHERE NOT EXISTS (
        SELECT 1 FROM provider_services ps WHERE ps.service_id = s.id
      )
    ''';
    await session.execute('''
      DELETE FROM order_lines
      WHERE order_id IN (
        SELECT id FROM orders WHERE service_id IN ($unowned)
      )
      ''');
    await session.execute('DELETE FROM orders WHERE service_id IN ($unowned)');
    await session.execute(
      'DELETE FROM appointments WHERE service_id IN ($unowned)',
    );
    await session.execute(
      'DELETE FROM wash_options WHERE service_id IN ($unowned)',
    );
    await session.execute(
      'DELETE FROM treatments WHERE service_id IN ($unowned)',
    );
    await session.execute(
      'DELETE FROM offerings WHERE service_id IN ($unowned)',
    );
    await session.execute(
      'DELETE FROM menu_items WHERE service_id IN ($unowned)',
    );
    await session.execute(
      'DELETE FROM time_slots WHERE service_id IN ($unowned)',
    );
    await session.execute('DELETE FROM services WHERE id IN ($unowned)');
  }

  Future<Map<String, dynamic>?> findSlot(String id) async {
    final row = await _one('SELECT * FROM time_slots WHERE id = @id', {
      'id': id,
    });
    return row == null ? null : _slot(row);
  }

  Future<List<Map<String, dynamic>>> slotsFor({
    required String serviceId,
    String? providerId,
    required String rangeStart,
    required String rangeEnd,
  }) async {
    final from = normalizeWallClock(rangeStart);
    final to = normalizeWallClock(rangeEnd);
    final Result rows;
    if (providerId == null) {
      rows = await _connection.execute(
        Sql.named('''
          SELECT * FROM time_slots
          WHERE service_id = @serviceId
            AND starts_at >= @from
            AND starts_at < @to
          ORDER BY starts_at
          '''),
        parameters: {'serviceId': serviceId, 'from': from, 'to': to},
      );
    } else {
      rows = await _connection.execute(
        Sql.named('''
          SELECT * FROM time_slots
          WHERE service_id = @serviceId
            AND provider_id = @providerId
            AND starts_at >= @from
            AND starts_at < @to
          ORDER BY starts_at
          '''),
        parameters: {
          'serviceId': serviceId,
          'providerId': providerId,
          'from': from,
          'to': to,
        },
      );
    }
    return [for (final row in rows) _slot(row.toColumnMap())];
  }

  Future<void> removeSlot(String id) async {
    await _connection.execute(
      Sql.named('''
        DELETE FROM time_slots t
        WHERE t.id = @id
          AND t.booked_count = 0
          AND NOT EXISTS (
            SELECT 1 FROM appointments a
            WHERE a.slot_id = t.id
          )
        '''),
      parameters: {'id': id},
    );
  }

  Future<void> publishSlot(Map<String, dynamic> slot) async {
    await _connection.execute(
      Sql.named('''
        INSERT INTO time_slots (
          id, provider_id, service_id, starts_at, duration_minutes,
          capacity, booked_count
        ) VALUES (
          @id, @providerId, @serviceId, @startsAt, @durationMinutes,
          @capacity, @bookedCount
        )
        ON CONFLICT (id) DO UPDATE SET
          provider_id = EXCLUDED.provider_id,
          service_id = EXCLUDED.service_id,
          starts_at = EXCLUDED.starts_at,
          duration_minutes = EXCLUDED.duration_minutes,
          capacity = EXCLUDED.capacity,
          booked_count = time_slots.booked_count
        '''),
      parameters: {
        'id': slot['id'],
        'providerId': slot['providerId'],
        'serviceId': slot['serviceId'],
        'startsAt': normalizeWallClock(slot['start'] as String),
        'durationMinutes': asInt(slot['durationMinutes']),
        'capacity': asInt(slot['capacity']),
        'bookedCount': asInt(slot['bookedCount']),
      },
    );
  }

  Future<Map<String, dynamic>?> activeAppointmentFor({
    required String userId,
    required String slotId,
  }) async {
    final row = await _one(
      '''
      SELECT * FROM appointments
      WHERE user_id = @userId AND slot_id = @slotId
        AND status IN ('booked', 'pending')
      ''',
      {'userId': userId, 'slotId': slotId},
    );
    return row == null ? null : _appointment(row);
  }

  /// Holds the slot row, then increments capacity only when a seat remains.
  Future<Reservation> tryReserve({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    int? durationMinutes,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
  }) {
    return _connection.runTx((tx) async {
      final preview = await tx.execute(
        Sql.named('SELECT * FROM time_slots WHERE id = @id'),
        parameters: {'id': slotId},
      );
      if (preview.isEmpty) {
        return const Reservation.rejected('slotNotFound');
      }
      final slot = preview.first.toColumnMap();
      final minutes = durationMinutes ?? asInt(slot['duration_minutes']);
      final startAt = DateTime.parse(slot['starts_at'] as String);
      final covered = await _lockSlotsBetween(
        tx,
        providerId: slot['provider_id'] as String,
        serviceId: slot['service_id'] as String,
        start: wallClockIso(startAt),
        end: wallClockIso(startAt.add(Duration(minutes: minutes))),
      );
      if (covered.every((row) => row['id'] != slotId)) {
        return const Reservation.rejected('slotNotFound');
      }
      if (covered.any(
        (row) => asInt(row['booked_count']) >= asInt(row['capacity']),
      )) {
        return const Reservation.rejected('slotFull');
      }
      final existing = await tx.execute(
        Sql.named('''
          SELECT id FROM appointments
          WHERE user_id = @userId AND slot_id = @slotId
            AND status IN ('booked', 'pending')
          '''),
        parameters: {'userId': userId, 'slotId': slotId},
      );
      if (existing.isNotEmpty) {
        return const Reservation.rejected('alreadyBooked');
      }
      final offeringRows = await tx.execute(
        Sql.named('''
          SELECT auto_confirm FROM offerings
          WHERE provider_id = @providerId AND service_id = @serviceId
          '''),
        parameters: {
          'providerId': slot['provider_id'],
          'serviceId': slot['service_id'],
        },
      );
      final autoConfirm =
          offeringRows.isEmpty ||
          offeringRows.first.toColumnMap()['auto_confirm'] != false;
      final status = autoConfirm ? 'booked' : 'pending';
      for (final row in covered) {
        await tx.execute(
          Sql.named('''
            UPDATE time_slots
            SET booked_count = booked_count + 1
            WHERE id = @id
            '''),
          parameters: {'id': row['id']},
        );
      }
      await tx.execute(
        Sql.named('''
          INSERT INTO appointments (
            id, user_id, slot_id, provider_id, service_id, starts_at,
            duration_minutes, status, vehicle_label, price_cents, vehicle_ids,
            wash_id, wash_name, vehicle_washes
          ) VALUES (
            @id, @userId, @slotId, @providerId, @serviceId, @startsAt,
            @durationMinutes, @status, @vehicleLabel, @priceCents, @vehicleIds,
            @washId, @washName, @vehicleWashes
          )
          '''),
        parameters: {
          'id': appointmentId,
          'userId': userId,
          'slotId': slotId,
          'providerId': slot['provider_id'],
          'serviceId': slot['service_id'],
          'startsAt': slot['starts_at'],
          'durationMinutes': minutes,
          'status': status,
          'vehicleLabel': vehicleLabel,
          'priceCents': priceCents,
          'vehicleIds': _encodeVehicleIds(vehicleIds),
          'washId': washId,
          'washName': washName,
          'vehicleWashes': _encodeVehicleWashes(vehicleWashes),
        },
      );
      return Reservation.booked({
        'id': appointmentId,
        'userId': userId,
        'slotId': slotId,
        'providerId': slot['provider_id'],
        'serviceId': slot['service_id'],
        'start': slot['starts_at'],
        'durationMinutes': minutes,
        'status': status,
        'vehicleLabel': vehicleLabel,
        'priceCents': priceCents,
        'vehicleIds': vehicleIds,
        'washId': washId,
        'washName': washName,
        'vehicleWashes': vehicleWashes,
      });
    });
  }

  Future<Map<String, dynamic>?> findAppointment(String id) async {
    final row = await _one('SELECT * FROM appointments WHERE id = @id', {
      'id': id,
    });
    return row == null ? null : _appointment(row);
  }

  Future<Reservation> reschedule({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    int? durationMinutes,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
  }) {
    return _connection.runTx((tx) async {
      final currentRows = await tx.execute(
        Sql.named('''
          SELECT * FROM appointments
          WHERE id = @id
          FOR UPDATE
          '''),
        parameters: {'id': appointmentId},
      );
      if (currentRows.isEmpty) {
        return const Reservation.rejected('appointmentNotFound');
      }
      final current = currentRows.first.toColumnMap();
      final revisingDeclined = current['status'] == 'declined';
      if (current['user_id'] != userId ||
          (current['status'] != 'booked' &&
              current['status'] != 'pending' &&
              !revisingDeclined)) {
        return const Reservation.rejected('appointmentNotFound');
      }
      final preview = await tx.execute(
        Sql.named('SELECT * FROM time_slots WHERE id = @id'),
        parameters: {'id': slotId},
      );
      if (preview.isEmpty) {
        return const Reservation.rejected('slotNotFound');
      }
      final slot = preview.first.toColumnMap();
      if (slot['service_id'] != current['service_id'] ||
          slot['provider_id'] != current['provider_id']) {
        return const Reservation.rejected('serviceMismatch');
      }
      if (slotId != current['slot_id']) {
        final clash = await tx.execute(
          Sql.named('''
            SELECT id FROM appointments
            WHERE user_id = @userId
              AND slot_id = @slotId
              AND status IN ('booked', 'pending')
              AND id <> @appointmentId
            '''),
          parameters: {
            'userId': userId,
            'slotId': slotId,
            'appointmentId': appointmentId,
          },
        );
        if (clash.isNotEmpty) {
          return const Reservation.rejected('alreadyBooked');
        }
      }
      final minutes = durationMinutes ?? asInt(slot['duration_minutes']);
      final previousStart = DateTime.parse(current['starts_at'] as String);
      final nextStart = DateTime.parse(slot['starts_at'] as String);
      final previous = revisingDeclined
          ? const <Map<String, dynamic>>[]
          : await _lockSlotsBetween(
              tx,
              providerId: current['provider_id'] as String,
              serviceId: current['service_id'] as String,
              start: wallClockIso(previousStart),
              end: wallClockIso(
                previousStart.add(
                  Duration(minutes: asInt(current['duration_minutes'])),
                ),
              ),
            );
      final next = await _lockSlotsBetween(
        tx,
        providerId: slot['provider_id'] as String,
        serviceId: slot['service_id'] as String,
        start: wallClockIso(nextStart),
        end: wallClockIso(nextStart.add(Duration(minutes: minutes))),
      );
      if (next.every((row) => row['id'] != slotId)) {
        return const Reservation.rejected('slotNotFound');
      }
      final held = {for (final row in previous) row['id'] as String};
      if (next.any(
        (row) =>
            !held.contains(row['id']) &&
            asInt(row['booked_count']) >= asInt(row['capacity']),
      )) {
        return const Reservation.rejected('slotFull');
      }
      final needed = {for (final row in next) row['id'] as String};
      for (final row in previous) {
        if (needed.contains(row['id'])) {
          continue;
        }
        await tx.execute(
          Sql.named('''
            UPDATE time_slots
            SET booked_count = booked_count - 1
            WHERE id = @id AND booked_count > 0
            '''),
          parameters: {'id': row['id']},
        );
      }
      for (final row in next) {
        if (held.contains(row['id'])) {
          continue;
        }
        await tx.execute(
          Sql.named('''
            UPDATE time_slots
            SET booked_count = booked_count + 1
            WHERE id = @id
            '''),
          parameters: {'id': row['id']},
        );
      }
      var nextStatus = current['status'] as String;
      if (revisingDeclined) {
        final offeringRows = await tx.execute(
          Sql.named('''
            SELECT auto_confirm FROM offerings
            WHERE provider_id = @providerId AND service_id = @serviceId
            '''),
          parameters: {
            'providerId': slot['provider_id'],
            'serviceId': slot['service_id'],
          },
        );
        final autoConfirm =
            offeringRows.isEmpty ||
            offeringRows.first.toColumnMap()['auto_confirm'] != false;
        nextStatus = autoConfirm ? 'booked' : 'pending';
      }
      await tx.execute(
        Sql.named('''
          UPDATE appointments
          SET slot_id = @slotId,
              starts_at = @startsAt,
              duration_minutes = @durationMinutes,
              vehicle_label = @vehicleLabel,
              price_cents = @priceCents,
              vehicle_ids = @vehicleIds,
              wash_id = @washId,
              wash_name = @washName,
              vehicle_washes = @vehicleWashes,
              status = @status,
              decline_message = @declineMessage,
              suggested_from = @suggestedFrom,
              suggested_until = @suggestedUntil
          WHERE id = @id
          '''),
        parameters: {
          'id': appointmentId,
          'slotId': slotId,
          'startsAt': slot['starts_at'],
          'durationMinutes': minutes,
          'vehicleLabel': vehicleLabel,
          'priceCents': priceCents,
          'vehicleIds': _encodeVehicleIds(vehicleIds),
          'washId': washId,
          'washName': washName,
          'vehicleWashes': _encodeVehicleWashes(vehicleWashes),
          'status': nextStatus,
          'declineMessage': revisingDeclined
              ? ''
              : (current['decline_message'] ?? ''),
          'suggestedFrom': revisingDeclined ? null : current['suggested_from'],
          'suggestedUntil': revisingDeclined
              ? null
              : current['suggested_until'],
        },
      );
      return Reservation.booked({
        'id': appointmentId,
        'userId': userId,
        'slotId': slotId,
        'providerId': slot['provider_id'],
        'serviceId': slot['service_id'],
        'start': slot['starts_at'],
        'durationMinutes': minutes,
        'status': nextStatus,
        'vehicleLabel': vehicleLabel,
        'priceCents': priceCents,
        'vehicleIds': vehicleIds,
        'washId': washId,
        'washName': washName,
        'vehicleWashes': vehicleWashes,
        'declineMessage': revisingDeclined
            ? ''
            : (current['decline_message'] ?? ''),
        'suggestedFrom': revisingDeclined ? null : current['suggested_from'],
        'suggestedUntil': revisingDeclined ? null : current['suggested_until'],
      });
    });
  }

  Future<Reservation> cancelAppointment({
    required String appointmentId,
    required String userId,
  }) {
    return _connection.runTx((tx) async {
      final currentRows = await tx.execute(
        Sql.named('''
          SELECT * FROM appointments
          WHERE id = @id
          FOR UPDATE
          '''),
        parameters: {'id': appointmentId},
      );
      if (currentRows.isEmpty) {
        return const Reservation.rejected('appointmentNotFound');
      }
      final current = currentRows.first.toColumnMap();
      final decliningVisit = current['status'] == 'declined';
      if (current['user_id'] != userId ||
          (current['status'] != 'booked' &&
              current['status'] != 'pending' &&
              !decliningVisit)) {
        return const Reservation.rejected('appointmentNotFound');
      }
      if (!decliningVisit) {
        final startAt = DateTime.parse(current['starts_at'] as String);
        final covered = await _lockSlotsBetween(
          tx,
          providerId: current['provider_id'] as String,
          serviceId: current['service_id'] as String,
          start: wallClockIso(startAt),
          end: wallClockIso(
            startAt.add(Duration(minutes: asInt(current['duration_minutes']))),
          ),
        );
        for (final row in covered) {
          await tx.execute(
            Sql.named('''
              UPDATE time_slots
              SET booked_count = booked_count - 1
              WHERE id = @id AND booked_count > 0
              '''),
            parameters: {'id': row['id']},
          );
        }
      }
      await tx.execute(
        Sql.named('''
          UPDATE appointments
          SET status = 'cancelled'
          WHERE id = @id
          '''),
        parameters: {'id': appointmentId},
      );
      final appointment = _appointment(current);
      appointment['status'] = 'cancelled';
      return Reservation.booked(appointment);
    });
  }

  Future<Reservation> confirmAppointment({
    required String appointmentId,
    required String providerId,
  }) {
    return _connection.runTx((tx) async {
      final currentRows = await tx.execute(
        Sql.named('''
          SELECT * FROM appointments
          WHERE id = @id
          FOR UPDATE
          '''),
        parameters: {'id': appointmentId},
      );
      if (currentRows.isEmpty) {
        return const Reservation.rejected('appointmentNotFound');
      }
      final current = currentRows.first.toColumnMap();
      if (current['provider_id'] != providerId ||
          current['status'] != 'pending') {
        return const Reservation.rejected('appointmentNotFound');
      }
      await tx.execute(
        Sql.named('''
          UPDATE appointments
          SET status = 'booked'
          WHERE id = @id
          '''),
        parameters: {'id': appointmentId},
      );
      final appointment = _appointment(current);
      appointment['status'] = 'booked';
      return Reservation.booked(appointment);
    });
  }

  Future<Reservation> declineAppointment({
    required String appointmentId,
    required String providerId,
    required String message,
    required String suggestedFrom,
    required String suggestedUntil,
  }) {
    return _connection.runTx((tx) async {
      final note = message.trim();
      if (note.isEmpty) {
        return const Reservation.rejected('missingDeclineMessage');
      }
      final fromText = suggestedFrom.trim();
      final untilText = suggestedUntil.trim();
      String? storedFrom;
      String? storedUntil;
      if (fromText.isNotEmpty || untilText.isNotEmpty) {
        final from = DateTime.tryParse(fromText);
        final until = DateTime.tryParse(untilText);
        if (from == null ||
            until == null ||
            DateTime(
              until.year,
              until.month,
              until.day,
            ).isBefore(DateTime(from.year, from.month, from.day))) {
          return const Reservation.rejected('invalidSuggestedRange');
        }
        storedFrom = fromText;
        storedUntil = untilText;
      }
      final currentRows = await tx.execute(
        Sql.named('''
          SELECT * FROM appointments
          WHERE id = @id
          FOR UPDATE
          '''),
        parameters: {'id': appointmentId},
      );
      if (currentRows.isEmpty) {
        return const Reservation.rejected('appointmentNotFound');
      }
      final current = currentRows.first.toColumnMap();
      if (current['provider_id'] != providerId ||
          current['status'] != 'pending') {
        return const Reservation.rejected('appointmentNotFound');
      }
      final startAt = DateTime.parse(current['starts_at'] as String);
      final covered = await _lockSlotsBetween(
        tx,
        providerId: current['provider_id'] as String,
        serviceId: current['service_id'] as String,
        start: wallClockIso(startAt),
        end: wallClockIso(
          startAt.add(Duration(minutes: asInt(current['duration_minutes']))),
        ),
      );
      for (final row in covered) {
        await tx.execute(
          Sql.named('''
            UPDATE time_slots
            SET booked_count = booked_count - 1
            WHERE id = @id AND booked_count > 0
            '''),
          parameters: {'id': row['id']},
        );
      }
      await tx.execute(
        Sql.named('''
          UPDATE appointments
          SET status = 'declined',
              decline_message = @message,
              suggested_from = @suggestedFrom,
              suggested_until = @suggestedUntil
          WHERE id = @id
          '''),
        parameters: {
          'id': appointmentId,
          'message': note,
          'suggestedFrom': storedFrom,
          'suggestedUntil': storedUntil,
        },
      );
      final appointment = _appointment(current);
      appointment['status'] = 'declined';
      appointment['declineMessage'] = note;
      appointment['suggestedFrom'] = storedFrom;
      appointment['suggestedUntil'] = storedUntil;
      return Reservation.booked(appointment);
    });
  }

  Future<List<Map<String, dynamic>>> appointmentsForUser(String userId) async {
    final rows = await _connection.execute(
      Sql.named('SELECT * FROM appointments WHERE user_id = @userId'),
      parameters: {'userId': userId},
    );
    return [for (final row in rows) _appointment(row.toColumnMap())];
  }

  Future<List<Map<String, dynamic>>> appointmentsForProvider(
    String providerId,
  ) async {
    final rows = await _connection.execute(
      Sql.named('SELECT * FROM appointments WHERE provider_id = @providerId'),
      parameters: {'providerId': providerId},
    );
    return [for (final row in rows) _appointment(row.toColumnMap())];
  }

  Future<Map<String, dynamic>?> findItem(String id) async {
    final row = await _one('SELECT * FROM menu_items WHERE id = @id', {
      'id': id,
    });
    return row == null ? null : _menuItem(row);
  }

  Future<List<Map<String, dynamic>>> itemsFor({
    required String serviceId,
    required String providerId,
  }) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT * FROM menu_items
        WHERE service_id = @serviceId AND provider_id = @providerId
        ORDER BY name
        '''),
      parameters: {'serviceId': serviceId, 'providerId': providerId},
    );
    return [for (final row in rows) _menuItem(row.toColumnMap())];
  }

  Future<void> publishItem(Map<String, dynamic> item) async {
    await _connection.execute(
      Sql.named('''
        INSERT INTO menu_items (
          id, provider_id, service_id, name, description, price_cents,
          available_from, available_until
        ) VALUES (
          @id, @providerId, @serviceId, @name, @description, @priceCents,
          @availableFrom, @availableUntil
        )
        ON CONFLICT (id) DO UPDATE SET
          provider_id = EXCLUDED.provider_id,
          service_id = EXCLUDED.service_id,
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          price_cents = EXCLUDED.price_cents,
          available_from = EXCLUDED.available_from,
          available_until = EXCLUDED.available_until
        '''),
      parameters: {
        'id': item['id'],
        'providerId': item['providerId'],
        'serviceId': item['serviceId'],
        'name': item['name'],
        'description': item['description'],
        'priceCents': asInt(item['priceCents']),
        'availableFrom': normalizeWallClock(item['availableFrom'] as String),
        'availableUntil': normalizeWallClock(item['availableUntil'] as String),
      },
    );
  }

  Future<void> saveOrder(Map<String, dynamic> order) async {
    final lines = (order['lines'] as List).cast<Map<String, dynamic>>();
    await _connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO orders (
            id, user_id, provider_id, service_id, placed_at, status
          ) VALUES (
            @id, @userId, @providerId, @serviceId, @placedAt, @status
          )
          '''),
        parameters: {
          'id': order['id'],
          'userId': order['userId'],
          'providerId': order['providerId'],
          'serviceId': order['serviceId'],
          'placedAt': normalizeWallClock(order['placedAt'] as String),
          'status': order['status'],
        },
      );
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        await tx.execute(
          Sql.named('''
            INSERT INTO order_lines (
              order_id, position, item_id, name, quantity, unit_price_cents
            ) VALUES (
              @orderId, @position, @itemId, @name, @quantity, @unitPriceCents
            )
            '''),
          parameters: {
            'orderId': order['id'],
            'position': index,
            'itemId': line['itemId'],
            'name': line['name'],
            'quantity': asInt(line['quantity']),
            'unitPriceCents': asInt(line['unitPriceCents']),
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> ordersForUser(String userId) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT
          o.id, o.user_id, o.provider_id, o.service_id, o.placed_at, o.status,
          l.position, l.item_id, l.name AS line_name, l.quantity,
          l.unit_price_cents
        FROM orders o
        LEFT JOIN order_lines l ON l.order_id = o.id
        WHERE o.user_id = @userId
        ORDER BY o.placed_at, l.position
        '''),
      parameters: {'userId': userId},
    );
    final orders = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final map = row.toColumnMap();
      final order = orders.putIfAbsent(map['id'] as String, () {
        return {
          'id': map['id'],
          'userId': map['user_id'],
          'providerId': map['provider_id'],
          'serviceId': map['service_id'],
          'placedAt': map['placed_at'],
          'status': map['status'],
          'lines': <Map<String, dynamic>>[],
        };
      });
      if (map['position'] != null) {
        (order['lines'] as List<Map<String, dynamic>>).add({
          'itemId': map['item_id'],
          'name': map['line_name'],
          'quantity': asInt(map['quantity']),
          'unitPriceCents': asInt(map['unit_price_cents']),
        });
      }
    }
    return orders.values.toList();
  }

  Future<Map<String, dynamic>> findProfile(String accountId) async {
    final profile = await _one(
      '''
      SELECT account_id, first_name, surname, address, contact_number
      FROM customer_profiles
      WHERE account_id = @accountId
      ''',
      {'accountId': accountId},
    );
    final vehicles = await _connection.execute(
      Sql.named('''
        SELECT id, name, vehicle_type, registration
        FROM vehicles
        WHERE account_id = @accountId
        ORDER BY position
        '''),
      parameters: {'accountId': accountId},
    );
    return {
      'accountId': accountId,
      'firstName': profile?['first_name'] ?? '',
      'surname': profile?['surname'] ?? '',
      'address': profile?['address'] ?? '',
      'contactNumber': profile?['contact_number'] ?? '',
      'vehicles': [
        for (final row in vehicles)
          {
            'id': row.toColumnMap()['id'],
            'name': row.toColumnMap()['name'],
            'type': row.toColumnMap()['vehicle_type'],
            'registration': row.toColumnMap()['registration'] ?? '',
          },
      ],
    };
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final vehicles = (profile['vehicles'] as List).cast<Map<String, dynamic>>();
    await _connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO customer_profiles (
            account_id, first_name, surname, address, contact_number
          )
          VALUES (
            @accountId, @firstName, @surname, @address, @contactNumber
          )
          ON CONFLICT (account_id) DO UPDATE SET
            first_name = EXCLUDED.first_name,
            surname = EXCLUDED.surname,
            address = EXCLUDED.address,
            contact_number = EXCLUDED.contact_number
          '''),
        parameters: {
          'accountId': profile['accountId'],
          'firstName': profile['firstName'] ?? '',
          'surname': profile['surname'] ?? '',
          'address': profile['address'],
          'contactNumber': profile['contactNumber'],
        },
      );
      await tx.execute(
        Sql.named('DELETE FROM vehicles WHERE account_id = @accountId'),
        parameters: {'accountId': profile['accountId']},
      );
      for (var index = 0; index < vehicles.length; index++) {
        final vehicle = vehicles[index];
        await tx.execute(
          Sql.named('''
            INSERT INTO vehicles (
              id, account_id, name, vehicle_type, registration, position
            )
            VALUES (
              @id, @accountId, @name, @vehicleType, @registration, @position
            )
            '''),
          parameters: {
            'id': vehicle['id'],
            'accountId': profile['accountId'],
            'name': vehicle['name'],
            'vehicleType': vehicle['type'],
            'registration': vehicle['registration'] ?? '',
            'position': index,
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> _lockSlotsBetween(
    TxSession tx, {
    required String providerId,
    required String serviceId,
    required String start,
    required String end,
  }) async {
    final rows = await tx.execute(
      Sql.named('''
        SELECT * FROM time_slots
        WHERE provider_id = @providerId
          AND service_id = @serviceId
          AND starts_at >= @start
          AND starts_at < @end
        ORDER BY id
        FOR UPDATE
        '''),
      parameters: {
        'providerId': providerId,
        'serviceId': serviceId,
        'start': start,
        'end': end,
      },
    );
    return [for (final row in rows) row.toColumnMap()];
  }

  Future<List<Map<String, dynamic>>> washesFor({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT * FROM wash_options
        WHERE provider_id = @providerId AND service_id = @serviceId
        ORDER BY position, name
        '''),
      parameters: {'providerId': providerId, 'serviceId': serviceId},
    );
    return [for (final row in rows) _wash(row.toColumnMap())];
  }

  Future<void> replaceWashes({
    required String providerId,
    required String serviceId,
    required List<Map<String, dynamic>> washes,
  }) async {
    await _connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          DELETE FROM wash_options
          WHERE provider_id = @providerId AND service_id = @serviceId
          '''),
        parameters: {'providerId': providerId, 'serviceId': serviceId},
      );
      for (var index = 0; index < washes.length; index++) {
        final wash = washes[index];
        await tx.execute(
          Sql.named('''
            INSERT INTO wash_options (
              id, provider_id, service_id, name, description, duration_minutes,
              price_cents, hatch_duration_minutes, hatch_price_cents,
              sedan_duration_minutes, sedan_price_cents, suv_duration_minutes,
              suv_price_cents, position
            ) VALUES (
              @id, @providerId, @serviceId, @name, @description, @hatchMinutes,
              @hatchPrice, @hatchMinutes, @hatchPrice, @sedanMinutes, @sedanPrice,
              @suvMinutes, @suvPrice, @position
            )
            '''),
          parameters: {
            'id': wash['id'],
            'providerId': providerId,
            'serviceId': serviceId,
            'name': wash['name'],
            'description': wash['description'] ?? '',
            'hatchMinutes': _rateMinutes(wash, 'hatch'),
            'hatchPrice': _ratePrice(wash, 'hatch'),
            'sedanMinutes': _rateMinutes(wash, 'sedan'),
            'sedanPrice': _ratePrice(wash, 'sedan'),
            'suvMinutes': _rateMinutes(wash, 'suv'),
            'suvPrice': _ratePrice(wash, 'suv'),
            'position': index,
          },
        );
      }
    });
  }

  Future<void> seedWashesIfEmpty() async {
    final rows = await _connection.execute(
      'SELECT COUNT(*) AS n FROM wash_options',
    );
    if (asInt(rows.first.toColumnMap()['n']) > 0) {
      return;
    }
    const washes = [
      (
        'wash-quick',
        'Quick wash',
        'Wash and wipe exterior and tyre polish',
        60,
        15000,
      ),
      (
        'wash-full',
        'Full wash',
        'Wash and wipe exterior, interior vacuum, dash shine and tyre polish',
        120,
        28000,
      ),
      (
        'wash-wax',
        'Wax and detailing',
        'Full wash with Macguires polish and detailing',
        240,
        45000,
      ),
    ];
    for (var index = 0; index < washes.length; index++) {
      final wash = washes[index];
      await _connection.execute(
        Sql.named('''
          INSERT INTO wash_options (
            id, provider_id, service_id, name, description, duration_minutes,
            price_cents, hatch_duration_minutes, hatch_price_cents,
            sedan_duration_minutes, sedan_price_cents, suv_duration_minutes,
            suv_price_cents, position
          ) VALUES (
            @id, 'maegans-rides', 'car-wash', @name, @description, @durationMinutes,
            @priceCents, @durationMinutes, @priceCents, @durationMinutes, @priceCents,
            @durationMinutes, @priceCents, @position
          )
          '''),
        parameters: {
          'id': wash.$1,
          'name': wash.$2,
          'description': wash.$3,
          'durationMinutes': wash.$4,
          'priceCents': wash.$5,
          'position': index,
        },
      );
    }
  }

  /// Copies the original wash price and duration onto each vehicle type.
  Future<void> fillVehicleWashRates() async {
    await _connection.execute('''
      UPDATE wash_options SET
        hatch_duration_minutes = COALESCE(hatch_duration_minutes, duration_minutes),
        hatch_price_cents = COALESCE(hatch_price_cents, price_cents),
        sedan_duration_minutes = COALESCE(sedan_duration_minutes, duration_minutes),
        sedan_price_cents = COALESCE(sedan_price_cents, price_cents),
        suv_duration_minutes = COALESCE(suv_duration_minutes, duration_minutes),
        suv_price_cents = COALESCE(suv_price_cents, price_cents)
      ''');
  }

  /// Fills the starting descriptions when a wash was saved before they existed.
  Future<void> fillBlankWashDescriptions() async {
    const descriptions = [
      ('wash-quick', 'Wash and wipe exterior and tyre polish'),
      (
        'wash-full',
        'Wash and wipe exterior, interior vacuum, dash shine and tyre polish',
      ),
      ('wash-wax', 'Full wash with Macguires polish and detailing'),
    ];
    for (final wash in descriptions) {
      await _connection.execute(
        Sql.named('''
          UPDATE wash_options
          SET description = @description
          WHERE id = @id AND description = ''
          '''),
        parameters: {'id': wash.$1, 'description': wash.$2},
      );
    }
  }

  Future<Map<String, dynamic>?> _one(
    String sql,
    Map<String, dynamic> parameters,
  ) async {
    final rows = await _connection.execute(
      Sql.named(sql),
      parameters: parameters,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.toColumnMap();
  }

  Future<void> _seed(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final passwordHash = hashPassword(demoPassword);
    const accounts = [
      ('alex', 'alex@community.app', 'Alex', 'customer', null),
      ('jordan', 'jordan@community.app', 'Jordan', 'customer', null),
      ('sam', 'sam@community.app', 'Sam', 'provider', 'sam-shine'),
      ('jess', 'jess@community.app', 'Jess', 'provider', 'jess-kitchen'),
      ('riley', 'riley@community.app', 'Riley', 'provider', 'riley-studio'),
      ('maegan', 'maegan@community.app', 'Maegan', 'provider', 'maegans-rides'),
      (
        'maegan-admin',
        'maeganadmin@community.app',
        'Maegan Admin',
        'admin',
        null,
      ),
    ];
    for (final account in accounts) {
      await _connection.execute(
        Sql.named('''
          INSERT INTO accounts (
            id, email, display_name, role, provider_id, password_hash
          ) VALUES (
            @id, @email, @displayName, @role, @providerId, @passwordHash
          )
          '''),
        parameters: {
          'id': account.$1,
          'email': account.$2,
          'displayName': account.$3,
          'role': account.$4,
          'providerId': account.$5,
          'passwordHash': passwordHash,
        },
      );
    }

    const services = [
      (
        'car-wash',
        'Car wash',
        'Book a wash at a time that suits you.',
        'appointment',
        1,
      ),
      (
        'foodie',
        'Foodie',
        'Order meals cooks have planned for the day or week.',
        'order',
        2,
      ),
      (
        'beauty',
        'Beauty',
        'Reserve a treatment with someone nearby.',
        'appointment',
        3,
      ),
    ];
    for (final service in services) {
      await saveService({
        'id': service.$1,
        'name': service.$2,
        'summary': service.$3,
        'fulfillment': service.$4,
      });
      await _connection.execute(
        Sql.named('UPDATE services SET position = @position WHERE id = @id'),
        parameters: {'position': service.$5, 'id': service.$1},
      );
    }

    const providers = [
      (
        'sam-shine',
        "Sam's Shine",
        'Driveway and mobile washes, booked by the hour.',
        ['car-wash'],
      ),
      (
        'maegans-rides',
        "Maegan's Rides",
        'Exterior and interior washes, with a rinse while you wait.',
        ['car-wash'],
      ),
      (
        'jess-kitchen',
        "Jess's Kitchen",
        'Home-cooked meals for the week.',
        ['foodie'],
      ),
      (
        'riley-studio',
        'Riley Studio',
        'Cuts, colour, and treatments.',
        ['beauty'],
      ),
    ];
    for (final provider in providers) {
      await saveProvider({
        'id': provider.$1,
        'displayName': provider.$2,
        'bio': provider.$3,
        'serviceIds': provider.$4,
      });
    }

    for (final opening in const [
      ('sam-shine', 'car-wash'),
      ('maegans-rides', 'car-wash'),
      ('riley-studio', 'beauty'),
    ]) {
      for (final slot in _appointmentSlots(
        today: today,
        providerId: opening.$1,
        serviceId: opening.$2,
      )) {
        await publishSlot(slot);
      }
    }

    final from = wallClockIso(today);
    final until = wallClockIso(weekEnd);
    const meals = [
      (
        'lentil-stew',
        'Lentil stew',
        'Slow-cooked lentils with warm spices.',
        8500,
      ),
      (
        'chicken-bowl',
        'Herb chicken bowl',
        'Roasted chicken, greens, and grains.',
        9200,
      ),
      (
        'veggie-wrap',
        'Market veggie wrap',
        'Seasonal vegetables and hummus.',
        6800,
      ),
    ];
    for (final meal in meals) {
      await publishItem({
        'id': meal.$1,
        'providerId': 'jess-kitchen',
        'serviceId': 'foodie',
        'name': meal.$2,
        'description': meal.$3,
        'priceCents': meal.$4,
        'availableFrom': from,
        'availableUntil': until,
      });
    }
  }

  Future<List<Map<String, dynamic>>> offeringsFor(String serviceId) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT provider_id, service_id, name, description, open_hours,
               open_weekdays, weekday_hours, weekend_hours,
               advance_amount, advance_unit, open_for_amount, open_for_unit,
               auto_confirm, concurrent_bookings
        FROM offerings
        WHERE service_id = @serviceId
        ORDER BY name
        '''),
      parameters: {'serviceId': serviceId},
    );
    return [for (final row in rows) _offering(row.toColumnMap())];
  }

  Future<Map<String, dynamic>?> findOffering({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT provider_id, service_id, name, description, open_hours,
               open_weekdays, weekday_hours, weekend_hours,
               advance_amount, advance_unit, open_for_amount, open_for_unit,
               auto_confirm, concurrent_bookings
        FROM offerings
        WHERE provider_id = @providerId AND service_id = @serviceId
        '''),
      parameters: {'providerId': providerId, 'serviceId': serviceId},
    );
    if (rows.isEmpty) {
      return null;
    }
    return _offering(rows.first.toColumnMap());
  }

  Future<void> saveOffering(Map<String, dynamic> offering) async {
    await _connection.execute(
      Sql.named('''
        INSERT INTO offerings (
          provider_id, service_id, name, description, open_hours, open_weekdays,
          weekday_hours, weekend_hours, advance_amount, advance_unit,
          open_for_amount, open_for_unit, auto_confirm, concurrent_bookings
        ) VALUES (
          @providerId, @serviceId, @name, @description, @openHours, @openWeekdays,
          @weekdayHours, @weekendHours, @advanceAmount, @advanceUnit,
          @openForAmount, @openForUnit, @autoConfirm, @concurrentBookings
        )
        ON CONFLICT (provider_id, service_id) DO UPDATE
        SET name = EXCLUDED.name,
            description = EXCLUDED.description,
            open_hours = EXCLUDED.open_hours,
            open_weekdays = EXCLUDED.open_weekdays,
            weekday_hours = EXCLUDED.weekday_hours,
            weekend_hours = EXCLUDED.weekend_hours,
            advance_amount = EXCLUDED.advance_amount,
            advance_unit = EXCLUDED.advance_unit,
            open_for_amount = EXCLUDED.open_for_amount,
            open_for_unit = EXCLUDED.open_for_unit,
            auto_confirm = EXCLUDED.auto_confirm,
            concurrent_bookings = EXCLUDED.concurrent_bookings
        '''),
      parameters: {
        'providerId': offering['providerId'],
        'serviceId': offering['serviceId'],
        'name': offering['name'],
        'description': offering['description'] ?? '',
        'openHours': _encodeHours(offering['openHours'] as List? ?? const []),
        'openWeekdays': _encodeHours(
          offering['openWeekdays'] as List? ?? const [],
        ),
        'weekdayHours': _encodeHours(
          offering['weekdayHours'] as List? ?? const [],
        ),
        'weekendHours': _encodeHours(
          offering['weekendHours'] as List? ?? const [],
        ),
        'advanceAmount': offering['advanceAmount'] ?? 0,
        'advanceUnit': offering['advanceUnit'] ?? 'hour',
        'openForAmount': offering['openForAmount'] ?? 1,
        'openForUnit': offering['openForUnit'] ?? 'week',
        'autoConfirm': offering['autoConfirm'] ?? true,
        'concurrentBookings': offering['concurrentBookings'] ?? 1,
      },
    );
  }

  Future<List<Map<String, dynamic>>> treatmentsFor({
    required String providerId,
    required String serviceId,
  }) async {
    final rows = await _connection.execute(
      Sql.named('''
        SELECT id, provider_id, service_id, name, description,
               duration_minutes, price_cents, position
        FROM treatments
        WHERE provider_id = @providerId AND service_id = @serviceId
        ORDER BY position, name
        '''),
      parameters: {'providerId': providerId, 'serviceId': serviceId},
    );
    return [for (final row in rows) _treatment(row.toColumnMap())];
  }

  Future<void> replaceTreatments({
    required String providerId,
    required String serviceId,
    required List<Map<String, dynamic>> treatments,
  }) async {
    await _connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          DELETE FROM treatments
          WHERE provider_id = @providerId AND service_id = @serviceId
          '''),
        parameters: {'providerId': providerId, 'serviceId': serviceId},
      );
      for (var index = 0; index < treatments.length; index++) {
        final treatment = treatments[index];
        await tx.execute(
          Sql.named('''
            INSERT INTO treatments (
              id, provider_id, service_id, name, description,
              duration_minutes, price_cents, position
            ) VALUES (
              @id, @providerId, @serviceId, @name, @description,
              @durationMinutes, @priceCents, @position
            )
            '''),
          parameters: {
            'id': treatment['id'],
            'providerId': providerId,
            'serviceId': serviceId,
            'name': treatment['name'],
            'description': treatment['description'] ?? '',
            'durationMinutes': asInt(treatment['durationMinutes']),
            'priceCents': asInt(treatment['priceCents']),
            'position': index,
          },
        );
      }
    });
  }
}

int asInt(Object? value) {
  return switch (value) {
    int() => value,
    BigInt() => value.toInt(),
    _ => throw StateError('Expected an integer, got $value'),
  };
}

Map<String, dynamic> _offering(Map<String, dynamic> row) {
  return {
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'name': row['name'],
    'description': row['description'] ?? '',
    'openHours': _decodeHours(row['open_hours']),
    'weekdayHours': _decodeHours(row['weekday_hours']),
    'weekendHours': _decodeHours(row['weekend_hours']),
    'openWeekdays': _decodeHours(row['open_weekdays']),
    'advanceAmount': asInt(row['advance_amount'] ?? 0),
    'advanceUnit': row['advance_unit'] ?? 'hour',
    'openForAmount': asInt(row['open_for_amount'] ?? 1),
    'openForUnit': row['open_for_unit'] ?? 'week',
    'autoConfirm': row['auto_confirm'] != false,
    'concurrentBookings': asInt(row['concurrent_bookings'] ?? 1),
  };
}

Map<String, dynamic> _treatment(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'name': row['name'],
    'description': row['description'] ?? '',
    'durationMinutes': asInt(row['duration_minutes']),
    'priceCents': asInt(row['price_cents']),
  };
}

String _encodeHours(List<dynamic> hours) {
  final unique = <int>{for (final hour in hours) asInt(hour)};
  final sorted = unique.toList()..sort();
  return sorted.join(',');
}

List<int> _decodeHours(Object? value) {
  final raw = value as String? ?? '';
  if (raw.isEmpty) {
    return const [];
  }
  return [for (final part in raw.split(',')) int.parse(part)];
}

Map<String, dynamic> _notification(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'accountId': row['account_id'],
    'appointmentId': row['appointment_id'],
    'kind': row['kind'],
    'message': row['message'],
    'createdAt': row['created_at'],
    'visibleUntil': row['visible_until'],
    'read': row['read'] == true,
  };
}

Map<String, dynamic> _account(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'email': row['email'],
    'displayName': row['display_name'],
    'role': row['role'],
    'providerId': row['provider_id'],
  };
}

Map<String, dynamic> _service(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'summary': row['summary'],
    'fulfillment': row['fulfillment'],
    'active': row['active'] != false,
  };
}

Map<String, dynamic> _slot(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'start': row['starts_at'],
    'durationMinutes': asInt(row['duration_minutes']),
    'capacity': asInt(row['capacity']),
    'bookedCount': asInt(row['booked_count']),
  };
}

Map<String, dynamic> _appointment(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'userId': row['user_id'],
    'slotId': row['slot_id'],
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'start': row['starts_at'],
    'durationMinutes': asInt(row['duration_minutes']),
    'status': row['status'],
    'vehicleLabel': row['vehicle_label'],
    'priceCents': row['price_cents'] == null ? null : asInt(row['price_cents']),
    'vehicleIds': _decodeVehicleIds(row['vehicle_ids']),
    'washId': row['wash_id'],
    'washName': row['wash_name'],
    'vehicleWashes': _decodeVehicleWashes(row['vehicle_washes']),
    'declineMessage': row['decline_message'] ?? '',
    'suggestedFrom': row['suggested_from'],
    'suggestedUntil': row['suggested_until'],
  };
}

Map<String, dynamic> _wash(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'name': row['name'],
    'description': row['description'] ?? '',
    'durationMinutes': _storedMinutes(row, 'hatch_duration_minutes'),
    'priceCents': _storedPrice(row, 'hatch_price_cents'),
    'rates': {
      'hatch': {
        'durationMinutes': _storedMinutes(row, 'hatch_duration_minutes'),
        'priceCents': _storedPrice(row, 'hatch_price_cents'),
      },
      'sedan': {
        'durationMinutes': _storedMinutes(row, 'sedan_duration_minutes'),
        'priceCents': _storedPrice(row, 'sedan_price_cents'),
      },
      'suv': {
        'durationMinutes': _storedMinutes(row, 'suv_duration_minutes'),
        'priceCents': _storedPrice(row, 'suv_price_cents'),
      },
    },
  };
}

int _storedMinutes(Map<String, dynamic> row, String column) {
  return asInt(row[column] ?? row['duration_minutes']);
}

int _storedPrice(Map<String, dynamic> row, String column) {
  return asInt(row[column] ?? row['price_cents']);
}

int _rateMinutes(Map<String, dynamic> wash, String type) {
  final rates = wash['rates'];
  if (rates is Map && rates[type] is Map) {
    final minutes = (rates[type] as Map)['durationMinutes'];
    if (minutes != null) {
      return asInt(minutes);
    }
  }
  return asInt(wash['durationMinutes']);
}

int _ratePrice(Map<String, dynamic> wash, String type) {
  final rates = wash['rates'];
  if (rates is Map && rates[type] is Map) {
    final price = (rates[type] as Map)['priceCents'];
    if (price != null) {
      return asInt(price);
    }
  }
  return asInt(wash['priceCents']);
}

Map<String, dynamic> _menuItem(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'providerId': row['provider_id'],
    'serviceId': row['service_id'],
    'name': row['name'],
    'description': row['description'],
    'priceCents': asInt(row['price_cents']),
    'availableFrom': row['available_from'],
    'availableUntil': row['available_until'],
  };
}

List<Map<String, dynamic>> _groupProviders(Result rows) {
  final grouped = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final map = row.toColumnMap();
    final id = map['id'] as String;
    final provider = grouped.putIfAbsent(id, () {
      return {
        'id': id,
        'displayName': map['display_name'],
        'bio': map['bio'],
        'serviceIds': <String>[],
        'inactiveServiceIds': <String>[],
        'active': map['provider_active'] != false,
      };
    });
    final serviceId = map['service_id'];
    if (serviceId != null) {
      (provider['serviceIds'] as List<String>).add(serviceId as String);
      if (map['active'] == false) {
        (provider['inactiveServiceIds'] as List<String>).add(
          serviceId as String,
        );
      }
    }
  }
  return grouped.values.toList();
}

final class _OpeningSchedule {
  const _OpeningSchedule({
    required this.weekdayHours,
    required this.weekendHours,
    required this.sharedHours,
    required this.weekdays,
    required this.advanceAmount,
    required this.advanceUnit,
    required this.openForAmount,
    required this.openForUnit,
  });

  final List<int> weekdayHours;
  final List<int> weekendHours;
  final List<int> sharedHours;
  final List<int> weekdays;
  final int advanceAmount;
  final String advanceUnit;
  final int openForAmount;
  final String openForUnit;
}

DateTime _calendarDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _nextCalendarWeek(DateTime day) {
  final today = _calendarDay(day);
  final untilMonday = (DateTime.monday - today.weekday + 7) % 7;
  return today.add(Duration(days: untilMonday == 0 ? 7 : untilMonday));
}

DateTime _windowStart(DateTime now, _OpeningSchedule schedule) {
  final today = _calendarDay(now);
  return switch (schedule.advanceUnit) {
    'day' => today.add(Duration(days: schedule.advanceAmount)),
    'week' => today.add(Duration(days: 7 * schedule.advanceAmount)),
    'month' => DateTime(
      today.year,
      today.month + schedule.advanceAmount,
      today.day,
    ),
    'nextWeek' => _nextCalendarWeek(today),
    _ => now.add(Duration(hours: schedule.advanceAmount)),
  };
}

DateTime _windowUntil(DateTime earliest, _OpeningSchedule schedule) {
  final startDay = _calendarDay(earliest);
  return switch (schedule.openForUnit) {
    'day' => startDay.add(Duration(days: schedule.openForAmount)),
    'month' => DateTime(
      startDay.year,
      startDay.month + schedule.openForAmount,
      startDay.day,
    ),
    _ => startDay.add(Duration(days: 7 * schedule.openForAmount)),
  };
}

List<DateTime> _bookingDays(DateTime now, _OpeningSchedule schedule) {
  final earliest = _windowStart(now, schedule);
  final until = _windowUntil(earliest, schedule);
  var day = _calendarDay(earliest);
  final last = _calendarDay(until.subtract(const Duration(microseconds: 1)));
  if (last.isBefore(day)) {
    return const [];
  }
  final days = <DateTime>[];
  while (!day.isAfter(last) && days.length < 366) {
    days.add(day);
    day = day.add(const Duration(days: 1));
  }
  return days;
}

bool _withinBookingWindow(
  DateTime start,
  DateTime now,
  _OpeningSchedule schedule,
) {
  final earliest = _windowStart(now, schedule);
  final until = _windowUntil(earliest, schedule);
  final opened = schedule.advanceUnit == 'hour' && schedule.advanceAmount == 0
      ? start.isAfter(now)
      : !start.isBefore(earliest);
  return opened && start.isBefore(until);
}

List<int> _hoursOn(_OpeningSchedule schedule, int weekday) {
  if (schedule.weekdayHours.isEmpty && schedule.weekendHours.isEmpty) {
    return schedule.sharedHours;
  }
  return weekday >= DateTime.saturday
      ? schedule.weekendHours
      : schedule.weekdayHours;
}

List<int> _openingHours(String serviceId) {
  if (serviceId == 'car-wash') {
    return [8, 9, 10, 11, 12, 13, 14, 15, 16];
  }
  return [9, 11, 13, 15];
}

List<Map<String, dynamic>> _appointmentSlots({
  required DateTime today,
  required String providerId,
  required String serviceId,
}) {
  final slots = <Map<String, dynamic>>[];
  for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
    final day = today.add(Duration(days: dayOffset));
    for (final hour in _openingHours(serviceId)) {
      final start = DateTime(day.year, day.month, day.day, hour);
      slots.add({
        'id': _slotId(
          serviceId: serviceId,
          providerId: providerId,
          start: start,
        ),
        'providerId': providerId,
        'serviceId': serviceId,
        'start': wallClockIso(start),
        'durationMinutes': 60,
        'capacity': 1,
        'bookedCount': 0,
      });
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

String _encodeVehicleWashes(Map<String, String> washes) {
  return [
    for (final entry in washes.entries) '${entry.key}:${entry.value}',
  ].join(',');
}

Map<String, String> _decodeVehicleWashes(Object? value) {
  final raw = value as String? ?? '';
  if (raw.isEmpty) {
    return const {};
  }
  final washes = <String, String>{};
  for (final part in raw.split(',')) {
    final splitAt = part.indexOf(':');
    if (splitAt <= 0) {
      continue;
    }
    washes[part.substring(0, splitAt)] = part.substring(splitAt + 1);
  }
  return washes;
}

String _encodeVehicleIds(List<String> ids) => ids.join(',');

List<String> _decodeVehicleIds(Object? value) {
  final raw = value as String? ?? '';
  if (raw.isEmpty) {
    return const [];
  }
  return raw.split(',');
}

String _newToken() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
