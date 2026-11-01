// lib/utils/passkey_stub.dart
// ใช้นอกเบราว์เซอร์ (Dart VM ของเทสต์) — ไม่มี WebAuthn
import 'passkey.dart';

PasskeyAuthenticator createPlatformPasskeyAuthenticator() =>
    _UnsupportedPasskeyAuthenticator();

class _UnsupportedPasskeyAuthenticator implements PasskeyAuthenticator {
  @override
  bool isSupported() => false;

  @override
  Future<bool> isPlatformAuthenticatorAvailable() async => false;

  @override
  Future<Map<String, dynamic>?> create(Map<String, dynamic> publicKey) =>
      throw const PasskeyException(PasskeyErrorKind.unsupported);

  @override
  Future<Map<String, dynamic>?> get(Map<String, dynamic> publicKey) =>
      throw const PasskeyException(PasskeyErrorKind.unsupported);

  @override
  String defaultName() => 'passkey';
}
