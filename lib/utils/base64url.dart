// lib/utils/base64url.dart
import 'dart:convert';
import 'dart:typed_data';

/// Base64url ไม่มี padding — รูปแบบไบต์ทุกตัวของ WebAuthn ที่รับส่งกับ backend (challenge, credential id, ...)
String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// ถอด Base64url (มีหรือไม่มี padding ก็ได้ รับแบบมาตรฐาน +/ ด้วย) ถอดไม่ได้ = [FormatException]
Uint8List base64UrlDecodeLenient(String value) {
  var s = value.trim().replaceAll('+', '-').replaceAll('/', '_');
  s = s.replaceAll('=', '');
  final pad = (4 - s.length % 4) % 4;
  if (pad == 3) throw const FormatException('ความยาว Base64url ไม่ถูกต้อง');
  return base64Url.decode(s + '=' * pad);
}
