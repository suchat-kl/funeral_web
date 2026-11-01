// ค่าคงที่ของระบบ: ชื่อระบบ และชื่อที่เก็บข้อมูลในเบราว์เซอร์ (แยกจากระบบอื่นบนโดเมนเดียวกัน)
import 'package:flutter/material.dart';

/// ค่าคงที่ของระบบฌาปนกิจ — ชื่อที่แสดง และชื่อคีย์ของที่เก็บในเบราว์เซอร์
///
/// หน้าเว็บนี้วางที่ `https://inf.doh.go.th/funeral/` โดเมนเดียวกับสลิปภาษี (`/sliptax/`) และหักหนี้
/// ที่เก็บของเบราว์เซอร์ (localStorage / IndexedDB) ผูกกับ origin ไม่ใช่ path
/// ทุกคีย์ของระบบนี้จึงต้องขึ้นต้นด้วย `funeral_` และที่เก็บ token ใช้ชื่อของระบบนี้เอง
/// ไม่งั้น token สองระบบทับกัน และออกจากระบบที่หนึ่งจะลบ token ของอีกระบบไปด้วย
class AppConfig {
  AppConfig._();

  /// ชื่อระบบเต็ม (หัวหน้าเว็บ แถบบน หน้าต่างเข้าสู่ระบบ)
  static const String systemName = 'ระบบดาวน์โหลดไฟล์และใบเสร็จฌาปนกิจ';

  /// ชื่อสั้น (จอแคบ / manifest)
  static const String shortName = 'ฌาปนกิจ';

  /// ไอคอนของระบบบนแถบบน/เมนู/ส่วนท้าย
  static const IconData logoIcon = Icons.volunteer_activism;

  /// หน่วยงาน (บรรทัดรองใต้ชื่อระบบ)
  static const String orgName = 'กรมทางหลวง';

  /// ที่อยู่หลักของหน้าเว็บ (passkey ใช้ได้เฉพาะเมื่อเปิดจากโดเมนนี้ — RP ID inf.doh.go.th)
  static const String homeUrl = 'https://inf.doh.go.th/funeral/';

  /// ชื่อฐาน IndexedDB ของ flutter_secure_storage (สลิปภาษีใช้ SliptaxEncryptedStorage)
  static const String secureDbName = 'FuneralEncryptedStorage';

  /// ชื่อกุญแจเข้ารหัสของ flutter_secure_storage
  static const String securePublicKey = 'FuneralSecureStorage';

  /// localStorage: ธีมที่ผู้ใช้เลือก
  static const String themeStorageKey = 'funeral_theme';

  /// localStorage: ตรึงเมนูข้างไว้หรือไม่
  static const String menuPinnedKey = 'funeral_menu_pinned';

  /// ชื่อช่องสื่อสารระหว่างแท็บของ ThaID (ต้องตรงกับใน web/thaid_callback.html)
  static const String thaidChannelName = 'funeral_thaid';
}
