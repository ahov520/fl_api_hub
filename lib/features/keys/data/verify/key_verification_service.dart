/// Service for verifying API key connectivity and model availability.
///
/// Performs a lightweight authenticated call against the relay's
/// OpenAI-compatible `/v1/models` endpoint using the key as a Bearer token,
/// measuring latency and reporting whether the key works and how many models
/// are reachable. Mirrors all-api-hub's "API & model verification" feature.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Outcome of a single key verification attempt.
class KeyVerificationResult {
  /// Whether the endpoint responded with a successful (2xx) status.
  final bool success;

  /// Human-readable status message for the UI.
  final String message;

  /// Round-trip latency, when the request completed.
  final Duration? latency;

  /// Number of models returned by `/v1/models`, when available.
  final int? modelCount;

  const KeyVerificationResult({
    required this.success,
    required this.message,
    this.latency,
    this.modelCount,
  });
}

/// Verifies API keys against their relay's `/v1/models` endpoint.
class KeyVerificationService {
  final Dio _dio;

  KeyVerificationService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  /// Tests [apiKey] against `{baseUrl}/v1/models`.
  ///
  /// Never throws — every failure mode is folded into a
  /// [KeyVerificationResult] with `success == false`.
  Future<KeyVerificationResult> verify({
    required String baseUrl,
    required String apiKey,
  }) async {
    final url = '${_trimSlash(baseUrl)}/v1/models';
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          validateStatus: (_) => true, // handle non-2xx manually
        ),
      );
      stopwatch.stop();
      final latency = stopwatch.elapsed;
      final status = response.statusCode ?? 0;

      if (status >= 200 && status < 300) {
        final count = _countModels(response.data);
        return KeyVerificationResult(
          success: true,
          message: count != null ? '连接成功 · $count 个模型可用' : '连接成功',
          latency: latency,
          modelCount: count,
        );
      }
      if (status == 401 || status == 403) {
        return KeyVerificationResult(
          success: false,
          message: '密钥无效或权限不足（HTTP $status）',
          latency: latency,
        );
      }
      return KeyVerificationResult(
        success: false,
        message: '站点返回异常（HTTP $status）',
        latency: latency,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return KeyVerificationResult(
        success: false,
        message: _describeDioError(e),
      );
    } catch (e) {
      stopwatch.stop();
      return KeyVerificationResult(success: false, message: '验证失败：$e');
    }
  }

  /// Counts models in an OpenAI-compatible `/v1/models` response.
  int? _countModels(dynamic data) {
    if (data is Map<String, dynamic>) {
      final list = data['data'];
      if (list is List) return list.length;
    }
    return null;
  }

  String _describeDioError(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => '连接超时，站点无响应',
    DioExceptionType.connectionError => '无法连接到站点，请检查网络或代理',
    _ => '网络错误：${e.message ?? e.type.name}',
  };

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// Riverpod provider for [KeyVerificationService].
final keyVerificationServiceProvider = Provider<KeyVerificationService>((ref) {
  return KeyVerificationService();
});
