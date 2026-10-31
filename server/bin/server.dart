import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:community_api/community_database.dart';
import 'package:community_api/http_api.dart';

Future<void> main() async {
  final database = await CommunityDatabase.connectFromEnvironment();
  await database.applySchema();
  await database.seedIfEmpty();
  await database.seedJordanAccount();
  await database.seedAdminAccount();
  await database.seedWashesIfEmpty();
  await database.fillBlankWashDescriptions();
  await database.fillVehicleWashRates();
  await database.deleteUnownedServices();
  await database.ensureUpcomingOpenings();
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildApi(database));
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Community API listening on ${server.port}');
}
