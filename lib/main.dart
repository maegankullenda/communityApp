import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/app.dart';
import 'package:community_app/presentation/dependencies.dart';

void main() {
  const configured = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configured.isNotEmpty
      ? configured
      : Platform.isAndroid
      ? 'http://10.0.2.2:8080'
      : 'http://127.0.0.1:8080';
  runApp(
    ProviderScope(
      overrides: [apiBaseUrlProvider.overrideWithValue(baseUrl)],
      child: const CommunityApp(),
    ),
  );
}
