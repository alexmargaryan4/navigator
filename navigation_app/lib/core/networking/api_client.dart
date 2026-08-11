import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';
import '../errors/result.dart';

/// Thin wrapper around [http.Client] shared by every service datasource.
///
/// Centralizes timeout handling and translation of low-level transport
/// exceptions into user-safe [AppFailure]s, so that no raw exception
/// (e.g. `SocketException`) ever reaches the UI layer.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _defaultTimeout = Duration(seconds: 15);

  Future<Result<Map<String, dynamic>>> getJson(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response =
          await _client.get(uri, headers: headers).timeout(timeout);
      return _decode(response);
    } on SocketException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } on HttpException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } on FormatException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      return _decode(response);
    } on SocketException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } on HttpException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } on FormatException catch (e) {
      return Result.err(NetworkFailure(technicalDetail: e.toString()));
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  Result<Map<String, dynamic>> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Result.err(
        NetworkFailure(
          technicalDetail:
              'HTTP ${response.statusCode}: ${response.body}',
        ),
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return Result.ok(decoded);
      }
      // Some endpoints (e.g. geocoding FeatureCollection) return a bare
      // object too, but if a list ever slips through, wrap it so callers
      // have a consistent shape to work with.
      return Result.ok(<String, dynamic>{'data': decoded});
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  void dispose() => _client.close();
}
