// lib/utils/passkey.dart
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

import 'passkey_stub.dart'
    if (dart.library.js_interop) 'passkey_web.dart'
    as impl;

/// ข้อความเมื่อผู้ใช้กดยกเลิก/ปิดหน้าสแกน ใช้ข้อความเดียวกันทุกหน้าจอ
const String passkeyCancelledMessage =
    'ยกเลิกการยืนยันตัวตนด้วยลายนิ้วมือ/Windows Hello';

/// ที่อยู่หน้าเว็บที่ใช้ passkey ได้ (RP ID ของ backend = inf.doh.go.th ผู้ใช้ตัดสิน 20 ต.ค. 2569)
const String passkeyHomeUrl = AppConfig.homeUrl;

/// ชนิดข้อผิดพลาดของเบราว์เซอร์ที่หน้าจอต้องแจ้งต่างกัน
enum PasskeyErrorKind {
  /// ตัวยืนยันตัวตนนี้ลงทะเบียนกับบัญชีนี้ไว้แล้ว (InvalidStateError ตอนสร้าง)
  alreadyRegistered,

  /// หน้าเว็บไม่ได้เปิดจากที่อยู่ที่ passkey ผูกไว้ (SecurityError) เช่นเปิดตรงที่ backupdoh
  wrongSite,

  /// เบราว์เซอร์/เครื่องนี้ไม่รองรับ
  unsupported,

  /// อื่น ๆ
  failed,
}

/// ข้อผิดพลาดจาก navigator.credentials ([toString] คืนข้อความภาษาไทยให้ผู้ใช้อ่าน)
class PasskeyException implements Exception {
  final PasskeyErrorKind kind;
  final String? detail;

  const PasskeyException(this.kind, [this.detail]);

  String get message => switch (kind) {
    PasskeyErrorKind.alreadyRegistered =>
      'อุปกรณ์นี้ลงทะเบียนกับบัญชีนี้ไว้แล้ว ใช้เข้าสู่ระบบได้เลย',
    PasskeyErrorKind.wrongSite =>
      'ใช้ลายนิ้วมือ/Windows Hello ได้เมื่อเปิดระบบที่ $passkeyHomeUrl เท่านั้น',
    PasskeyErrorKind.unsupported =>
      'เบราว์เซอร์หรือเครื่องนี้ไม่รองรับการเข้าสู่ระบบด้วยลายนิ้วมือ/Windows Hello',
    PasskeyErrorKind.failed =>
      'ยืนยันตัวตนด้วยลายนิ้วมือ/Windows Hello ไม่สำเร็จ กรุณาลองใหม่',
  };

  @override
  String toString() => message;
}

/// ตัวเรียก WebAuthn ของเบราว์เซอร์ (navigator.credentials) — แยกเป็น interface ให้เทสต์ใส่ตัวปลอมได้
/// (เทสต์รันบน Dart VM ไม่มี navigator) แบบเดียวกับ thaidAuthorizer
///
/// [create] / [get] รับ `publicKey` ที่ backend ส่งมา (ไบต์เป็น Base64url) และคืนผลรูป JSON ของ WebAuthn
/// (PublicKeyCredential.toJSON: ไบต์เป็น Base64url ไม่มี padding) ส่งต่อให้ backend ได้ทันที
/// คืน null = ผู้ใช้กดยกเลิก/ปิดหน้าสแกน/หมดเวลา ข้อผิดพลาดอื่นโยน [PasskeyException]
/// ห้าม log ค่าที่รับและคืน
abstract class PasskeyAuthenticator {
  /// เบราว์เซอร์รองรับ WebAuthn และหน้าเว็บเป็น secure context (https หรือ localhost)
  /// ตรวจได้ทันที (ไม่ต้องรอ) จึงใช้ซ่อนปุ่ม/เมนูตอนสร้างหน้าจอได้
  bool isSupported();

  /// เครื่องนี้มีตัวสแกนในเครื่องที่ยืนยันผู้ใช้ได้ (ลายนิ้วมือ / Windows Hello / Touch ID)
  /// ใช้ PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable() ของเบราว์เซอร์
  /// เบราว์เซอร์ไม่มี PublicKeyCredential หรือถามแล้วผิดพลาด = false
  /// ตรวจก่อนสแกนทุกครั้งที่กดปุ่มเข้าสู่ระบบด้วยลายนิ้วมือ (ดู `ensurePasskeyAvailable`)
  Future<bool> isPlatformAuthenticatorAvailable();

  /// ลงทะเบียน passkey ใหม่ (navigator.credentials.create)
  Future<Map<String, dynamic>?> create(Map<String, dynamic> publicKey);

  /// ยืนยันตัวตนด้วย passkey ที่มีอยู่ (navigator.credentials.get)
  Future<Map<String, dynamic>?> get(Map<String, dynamic> publicKey);

  /// ชื่อตั้งต้นของ passkey ตามระบบปฏิบัติการ (ผู้ใช้แก้ได้)
  String defaultName();
}

/// เทสต์ใส่ตัวปลอมแทนตัวเรียกจริงของทั้งแอป (ปุ่มหน้าเข้าสู่ระบบ เมนูบัญชี หน้าต่างจัดการ passkey)
@visibleForTesting
PasskeyAuthenticator? passkeyAuthenticatorOverride;

/// ตัวเรียกของเบราว์เซอร์ (บน VM = ไม่รองรับ) หรือตัวปลอมของเทสต์
PasskeyAuthenticator createPasskeyAuthenticator() =>
    passkeyAuthenticatorOverride ?? impl.createPlatformPasskeyAuthenticator();
