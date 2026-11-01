import 'package:dio/dio.dart';

import '../utils/logger.dart';
import 'api_service.dart';

/// แนบ access token ทุกคำขอที่ต้องเข้าสู่ระบบ และเมื่อ backend ตอบ 401 (token หมดอายุ/ถูกยกเลิก)
/// ต่ออายุ token ด้วย refresh token แล้วยิงคำขอเดิมซ้ำหนึ่งครั้ง ต่ออายุไม่ได้ = ออกจากระบบ
///
/// backend ฌาปนกิจตอบ 401 `UNAUTHENTICATED` เมื่อ token ใช้ไม่ได้ และ 403 เมื่อบทบาทไม่พอ
/// (`FORBIDDEN`) หรือต้องเปลี่ยนรหัสผ่านก่อน (`PASSWORD_CHANGE_REQUIRED`) — 403 ไม่ใช่เรื่อง token จึงไม่ต่ออายุ
class AuthInterceptor extends Interceptor {
  final ApiService apiService;

  bool _isRefreshing = false;
  final List<Map<String, dynamic>> _pendingRequests = [];

  AuthInterceptor(this.apiService);

  /// เส้นที่ไม่ต้องยืนยันตัวตน: ไม่แนบ token และเจอ 401 ก็ไม่ต่ออายุ token
  /// - `/api/auth/login`, `/api/auth/login/2fa` (รหัสผิดตอบ 401 ต้องส่งให้หน้าจอแสดงข้อความ)
  /// - `/api/auth/refresh-token`
  /// - `/api/auth/public-thaid/` เข้าสู่ระบบ / ลงทะเบียน / ลืมรหัสผ่านด้วย ThaID
  /// - `/api/public/register/`, `/api/public/passkey/`, `/api/public/stats`
  ///
  /// `/api/public/general-files` **ไม่อยู่ในรายการนี้**: เข้าสู่ระบบอยู่ต้องแนบ token
  /// backend จึงกรองแบบฟอร์มตามประเภทบุคลากรของผู้ใช้ (ไม่แนบ = เห็นเฉพาะ "ทั้งหมด")
  static const List<String> publicEndpoints = [
    '/api/auth/login',
    '/api/auth/refresh-token',
    '/api/auth/public-thaid/',
    '/api/public/register/',
    '/api/public/passkey/',
    '/api/public/stats',
  ];

  static bool isPublicPath(String path) =>
      publicEndpoints.any((e) => path.contains(e));

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isPublicPath(options.path)) {
      final token = await apiService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);
    final requestPath = err.requestOptions.path;
    if (isPublicPath(requestPath) || requestPath.contains('/auth/logout')) {
      return handler.next(err);
    }
    // ยิงซ้ำหลังต่ออายุแล้วยังได้ 401 = ไม่ใช่เรื่อง token หมดอายุ ส่งต่อให้ผู้เรียก ไม่วนต่ออายุ
    if (err.requestOptions.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // กำลังต่ออายุอยู่: เข้าคิวรอ แล้วยิงซ้ำพร้อมกันเมื่อได้ token ใหม่
    if (_isRefreshing) {
      _pendingRequests.add({'options': err.requestOptions, 'handler': handler});
      return;
    }

    _isRefreshing = true;
    if (AppLogger.on) AppLogger.d('🔄 ต่ออายุ token');
    try {
      await apiService.refreshToken();
      _isRefreshing = false;
      final newToken = await apiService.getAccessToken();
      for (final pending in _pendingRequests) {
        final opts = pending['options'] as RequestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        _retryRequest(opts, pending['handler'] as ErrorInterceptorHandler);
      }
      _pendingRequests.clear();
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      _retryRequest(err.requestOptions, handler);
    } catch (e) {
      if (AppLogger.on) AppLogger.e('❌ ต่ออายุ token ไม่สำเร็จ: $e');
      _isRefreshing = false;
      for (final pending in _pendingRequests) {
        (pending['handler'] as ErrorInterceptorHandler).reject(err);
      }
      _pendingRequests.clear();
      handler.reject(err);
      // refreshToken() ออกจากระบบให้แล้วเมื่อไม่สำเร็จ
    }
  }

  /// ป้ายใน `RequestOptions.extra` ว่าคำขอนี้ถูกยิงซ้ำหลังต่ออายุ token แล้ว
  static const String _retriedKey = 'auth_retried';

  void _retryRequest(RequestOptions options, ErrorInterceptorHandler handler) {
    options.extra[_retriedKey] = true;
    apiService.dio
        .fetch(options)
        .then(
          handler.resolve,
          onError: (e) {
            if (e is DioException) {
              handler.reject(e);
            } else {
              handler.reject(DioException(requestOptions: options, error: e));
            }
          },
        );
  }
}
