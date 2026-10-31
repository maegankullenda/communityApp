import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final class ApiException implements Exception {
  ApiException({required this.status, required this.code});

  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

final class CommunityApi {
  CommunityApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  String? token;

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, dynamic>?> getObject(
    String path, {
    Map<String, String>? query,
  }) {
    return _send('GET', path, query: query, allowMissing: true).then((body) {
      if (body == null) {
        return null;
      }
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    });
  }

  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query).then((body) {
      return jsonDecode(body!) as List<dynamic>;
    });
  }

  Future<Map<String, dynamic>> postObject(
    String path,
    Map<String, dynamic> json,
  ) {
    return _send('POST', path, json: json).then((body) {
      return Map<String, dynamic>.from(jsonDecode(body!) as Map);
    });
  }

  Future<void> putObject(String path, Map<String, dynamic> json) {
    return _send('PUT', path, json: json).then((_) {});
  }

  Future<void> postEmpty(String path, Map<String, dynamic> json) {
    return _send('POST', path, json: json).then((_) {});
  }

  Future<void> delete(String path) {
    return _send('DELETE', path).then((_) {});
  }

  Future<String?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? json,
    bool allowMissing = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final request = http.Request(method, uri);
    if (token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }
    if (json != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(json);
    }
    final http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 8));
    } on SocketException {
      throw ApiException(status: 0, code: 'unavailable');
    } on http.ClientException {
      throw ApiException(status: 0, code: 'unavailable');
    } on TimeoutException {
      throw ApiException(status: 0, code: 'unavailable');
    }
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 404 && allowMissing) {
      return null;
    }
    if (streamed.statusCode == 204) {
      return null;
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      String code = 'requestFailed';
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] is String) {
          code = decoded['error'] as String;
        }
      }
      throw ApiException(status: streamed.statusCode, code: code);
    }
    return body;
  }
}
