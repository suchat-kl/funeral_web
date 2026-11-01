// lib/utils/passkey_web.dart
// ใช้ในเบราว์เซอร์เท่านั้น (เลือกด้วย conditional import ใน passkey.dart)
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'base64url.dart';
import 'passkey.dart';

PasskeyAuthenticator createPlatformPasskeyAuthenticator() =>
    _WebPasskeyAuthenticator();

/// เรียก navigator.credentials โดยแปลง Base64url ↔ ArrayBuffer เอง
/// ไม่พึ่ง PublicKeyCredential.parseCreationOptionsFromJSON / toJSON ที่เบราว์เซอร์รุ่นเก่ายังไม่มี
class _WebPasskeyAuthenticator implements PasskeyAuthenticator {
  @override
  bool isSupported() {
    try {
      return web.window.isSecureContext &&
          globalContext.has('PublicKeyCredential');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isPlatformAuthenticatorAvailable() async {
    if (!isSupported()) return false;
    try {
      final pkc = globalContext['PublicKeyCredential'] as JSObject;
      const method = 'isUserVerifyingPlatformAuthenticatorAvailable';
      if (!pkc.has(method)) return false;
      final available = await pkc
          .callMethod<JSPromise<JSBoolean>>(method.toJS)
          .toDart;
      return available.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> create(Map<String, dynamic> publicKey) async {
    final options =
        _toJs(_withBytes(publicKey, const {'challenge'}))
            as web.PublicKeyCredentialCreationOptions;
    final web.Credential? credential;
    try {
      credential = await web.window.navigator.credentials
          .create(web.CredentialCreationOptions(publicKey: options))
          .toDart;
    } catch (e) {
      return _handleError(e);
    }
    if (credential == null) return null;
    final pkc = credential as web.PublicKeyCredential;
    final response = pkc.response as web.AuthenticatorAttestationResponse;

    List<String>? transports;
    try {
      transports = response
          .getTransports()
          .toDart
          .map((s) => s.toDart)
          .toList();
    } catch (_) {
      transports = null; // เบราว์เซอร์รุ่นเก่าไม่มี getTransports
    }
    return _credentialJson(pkc, {
      'clientDataJSON': _b64(response.clientDataJSON),
      'attestationObject': _b64(response.attestationObject),
      'transports': ?transports,
    });
  }

  @override
  Future<Map<String, dynamic>?> get(Map<String, dynamic> publicKey) async {
    final options =
        _toJs(_withBytes(publicKey, const {'challenge'}))
            as web.PublicKeyCredentialRequestOptions;
    final web.Credential? credential;
    try {
      credential = await web.window.navigator.credentials
          .get(web.CredentialRequestOptions(publicKey: options))
          .toDart;
    } catch (e) {
      return _handleError(e);
    }
    if (credential == null) return null;
    final pkc = credential as web.PublicKeyCredential;
    final response = pkc.response as web.AuthenticatorAssertionResponse;
    final userHandle = response.userHandle;
    return _credentialJson(pkc, {
      'clientDataJSON': _b64(response.clientDataJSON),
      'authenticatorData': _b64(response.authenticatorData),
      'signature': _b64(response.signature),
      if (userHandle != null) 'userHandle': _b64(userHandle),
    });
  }

  @override
  String defaultName() {
    final ua = web.window.navigator.userAgent;
    if (ua.contains('Android')) return 'โทรศัพท์ Android';
    if (ua.contains('iPhone') || ua.contains('iPad')) return 'iPhone/iPad';
    if (ua.contains('Macintosh') || ua.contains('Mac OS X')) {
      return 'Touch ID (Mac)';
    }
    if (ua.contains('Windows')) return 'Windows Hello';
    return 'passkey';
  }

  /// ผลจากเบราว์เซอร์รูป JSON ของ WebAuthn (RegistrationResponseJSON / AuthenticationResponseJSON)
  Map<String, dynamic> _credentialJson(
    web.PublicKeyCredential pkc,
    Map<String, dynamic> response,
  ) {
    final id = _b64(pkc.rawId);
    return {
      'id': id,
      'rawId': id,
      'type': 'public-key',
      'response': response,
      'clientExtensionResults': <String, dynamic>{},
      'authenticatorAttachment': ?pkc.authenticatorAttachment,
    };
  }

  /// ข้อผิดพลาดของ navigator.credentials: ยกเลิก/หมดเวลา = null อย่างอื่นโยน [PasskeyException]
  Map<String, dynamic>? _handleError(Object e) {
    final name = _errorName(e);
    switch (name) {
      case 'NotAllowedError':
      case 'AbortError':
        return null;
      case 'InvalidStateError':
        throw const PasskeyException(PasskeyErrorKind.alreadyRegistered);
      case 'SecurityError':
        throw const PasskeyException(PasskeyErrorKind.wrongSite);
      case 'NotSupportedError':
        throw const PasskeyException(PasskeyErrorKind.unsupported);
      default:
        throw PasskeyException(PasskeyErrorKind.failed, name);
    }
  }

  /// ชื่อ DOMException (NotAllowedError, ...) — อ่านจาก property name ก่อน ไม่ได้จึงหาในข้อความ
  static String? _errorName(Object e) {
    try {
      // ignore: invalid_runtime_check_with_js_interop_types
      final js = e as JSObject;
      final name = js.getProperty<JSAny?>('name'.toJS);
      if (name != null && name.isA<JSString>()) {
        return (name as JSString).toDart;
      }
    } catch (_) {}
    final text = e.toString();
    for (final n in const [
      'NotAllowedError',
      'AbortError',
      'InvalidStateError',
      'SecurityError',
      'NotSupportedError',
    ]) {
      if (text.contains(n)) return n;
    }
    return null;
  }

  static String _b64(JSArrayBuffer buffer) =>
      base64UrlNoPad(buffer.toDart.asUint8List());

  /// สำเนาของ options ที่แปลงค่า Base64url เป็นไบต์: [topLevel] (challenge), user.id,
  /// และ id ของ excludeCredentials / allowCredentials
  static Map<String, dynamic> _withBytes(
    Map<String, dynamic> options,
    Set<String> topLevel,
  ) {
    final out = Map<String, dynamic>.from(options);
    for (final key in topLevel) {
      final v = out[key];
      if (v is String) out[key] = base64UrlDecodeLenient(v);
    }
    final user = out['user'];
    if (user is Map) {
      final u = Map<String, dynamic>.from(user);
      if (u['id'] is String) u['id'] = base64UrlDecodeLenient(u['id']);
      out['user'] = u;
    }
    for (final key in const ['excludeCredentials', 'allowCredentials']) {
      final list = out[key];
      if (list is List) {
        out[key] = [
          for (final d in list)
            if (d is Map)
              {
                ...Map<String, dynamic>.from(d),
                if (d['id'] is String) 'id': base64UrlDecodeLenient(d['id']),
              },
        ];
      }
    }
    return out;
  }

  /// แปลงค่าของ Dart เป็นค่าของ JS — ไบต์เป็น Uint8Array (jsify จะแปลงเป็น Array ของตัวเลขซึ่งใช้ไม่ได้)
  static JSAny? _toJs(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value.toJS;
    if (value is String) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is num) return value.toJS;
    if (value is Map) {
      final obj = JSObject();
      value.forEach((k, v) {
        final js = _toJs(v);
        if (js != null) obj.setProperty('$k'.toJS, js);
      });
      return obj;
    }
    if (value is Iterable) {
      return [for (final v in value) _toJs(v)].toJS;
    }
    return value.toString().toJS;
  }
}
