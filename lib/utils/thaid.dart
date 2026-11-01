// lib/utils/thaid.dart
import 'dart:async';

import 'package:universal_html/html.dart' as html;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';

/// ข้อความเมื่อผู้ใช้ยกเลิก ใช้ข้อความเดียวกันทุกหน้าจอ
const String thaidCancelledMessage = 'ผู้ใช้งานยกเลิกการใช้ ThaID';

/// ช่องสื่อสารระหว่างแท็บของเว็บเดียวกัน หน้า thaid_callback.html ที่ไม่มี window.opener (มือถือ)
/// ส่งผลมาทางนี้ ชื่อต้องตรงกับใน web/thaid_callback.html
const String thaidChannelName = AppConfig.thaidChannelName;

/// ตัวเปิด ThaID แล้วรอ state — แยกเป็นชนิดให้เทสต์ใส่ตัวปลอมแทนหน้าต่างของเบราว์เซอร์
/// คืน null = ผู้ใช้ยกเลิก
typedef ThaidAuthorizer =
    Future<String?> Function(ApiService api, {String purpose});

/// เทสต์ใส่ตัวปลอมแทน [thaidAuthorize] ของทั้งแอป (ปุ่มแถบบน หน้าเข้าสู่ระบบ ลงทะเบียน ลืมรหัสผ่าน)
@visibleForTesting
ThaidAuthorizer? thaidAuthorizerOverride;

/// ตัวเปิด ThaID ที่ใช้จริงตอนนี้ (ตัวปลอมของเทสต์ หรือ [thaidAuthorize])
ThaidAuthorizer get currentThaidAuthorizer =>
    thaidAuthorizerOverride ?? thaidAuthorize;

/// หน้า thaid_callback.html ของเว็บที่เปิดอยู่ ใช้ base href ของแอป (/funeral/)
/// เข้าผ่าน inf.doh.go.th dbdoh หรือ backupdoh ก็กลับมาที่เดิม
String thaidReturnUrl() {
  final base = html.document.baseUri ?? html.window.location.href;
  return Uri.parse(base).resolve('thaid_callback.html').toString();
}

/// เปิดหน้าต่าง ThaID ให้สแกน แล้วรอผล คืน state ที่ตรวจแล้วว่าตรงกับที่ส่งไป
/// ผู้เรียกนำ state ไปใช้กับเส้นของวัตถุประสงค์นั้น (login / register / reset)
/// คืน null ถ้าผู้ใช้ยกเลิก: กดยกเลิกในแอป ThaID หรือปิดหน้าต่างเอง ([thaidCancelledMessage])
///
/// เปิดหน้าต่างใหม่แทนการพาหน้านี้ไป
/// ต้องเรียกจากการกดปุ่มโดยตรง เพราะเบราว์เซอร์บล็อกหน้าต่างที่ไม่ได้เปิดจากการกด
/// จึงเปิดหน้าต่างเปล่าก่อน แล้วค่อยใส่ URL ของ ThaID เมื่อได้จาก backend
///
/// ขั้นตอน:
///   1. backend สุ่ม state ส่งไปกับ URL ของ ThaID หน้านี้เก็บ state ไว้
///   2. ผู้ใช้สแกน QR -> ThaID ส่ง state กลับมาที่ backend ตรวจว่าตรงกับที่ส่งไป
///   3. thaid_callback.html ส่ง state กลับมาทาง postMessage หน้านี้เทียบกับค่าที่เก็บไว้ ต้องตรงกัน
///   4. เข้าสู่ระบบกับ backend ด้วย state นั้น ใช้ได้ครั้งเดียว
///
/// มือถือ: แอป ThaID เปิดหน้า callback ใน**แท็บใหม่**ที่ไม่มี window.opener ข้อ 3 จึงไม่เกิด
/// หน้านี้จึงถามสถานะของ state จาก backend เป็นระยะ ([ApiService.thaidStatus]) และทันทีที่ผู้ใช้สลับกลับมาที่แท็บนี้
/// DONE / ERROR = ไปข้อ 4 (ผู้เรียกได้ผลหรือข้อความผิดพลาดจากเส้นของวัตถุประสงค์นั้น) GONE = ยกเลิกในแอป ThaID
/// หน้า callback แท็บใหม่ยังส่งผลมาทาง BroadcastChannel ([thaidChannelName]) ด้วย หน้านี้รู้ผลได้ทันทีแม้อยู่เบื้องหลัง
/// ได้ผลแล้วหน้านี้ปิดแท็บ ThaID ที่เปิดไว้ (auth.bora.dopa.go.th "กรุณาปิดหน้านี้") ให้เอง
/// ไม่งั้นผู้ใช้สลับแท็บแล้วไปเจอแท็บนั้นแทนแท็บของระบบ ต้องกด back เอง
///
/// [purpose] = วัตถุประสงค์ ([ApiService.thaidPurposeLogin] / [ApiService.thaidPurposeRegister] /
/// [ApiService.thaidPurposeReset]) — state ใช้ข้ามวัตถุประสงค์ไม่ได้
Future<String?> thaidAuthorize(
  ApiService api, {
  String purpose = ApiService.thaidPurposeLogin,
}) async {
  final popup = html.window.open(
    '',
    'thaid',
    'width=520,height=780,menubar=no,toolbar=no',
  );

  final String sentState;
  try {
    final start = await api.thaidStart(thaidReturnUrl(), purpose: purpose);
    sentState = start.state;
    popup.location.href = start.url;
  } catch (e) {
    popup.close();
    rethrow;
  }

  final done = Completer<String?>();
  late final StreamSubscription<html.MessageEvent> sub;
  StreamSubscription<dynamic>? channelSub;
  html.BroadcastChannel? channel;
  StreamSubscription<html.Event>? visibility;
  Timer? watcher;
  Timer? poller;

  void stopListening() {
    sub.cancel();
    channelSub?.cancel();
    channel?.close();
    visibility?.cancel();
    watcher?.cancel();
    poller?.cancel();
  }

  /// [closePopup] = ปิดแท็บ/หน้าต่าง ThaID ที่เปิดไว้ด้วย (ทางของมือถือ ที่แท็บนั้นค้างหน้า "กรุณาปิดหน้านี้")
  /// ทาง postMessage ไม่ปิด เพราะหน้า callback ในหน้าต่างนั้นแสดงผลแล้วปิดตัวเองตามเวลา
  void finish(Object? result, {bool isError = false, bool closePopup = true}) {
    if (done.isCompleted) return;
    stopListening();
    if (closePopup) {
      try {
        popup.close();
      } catch (_) {}
    }
    if (isError) {
      done.completeError(result!);
    } else {
      done.complete(result as String?);
    }
  }

  /// ผลที่หน้า callback ส่งมา (state ตรวจแล้ว)
  void handleResult(Map data, {bool closePopup = true}) {
    // ผู้ใช้กดยกเลิกในแอป ThaID (รหัส user_denied) = ยกเลิก ไม่ใช่ข้อผิดพลาด
    if (data['cancelled'] == true) {
      finish(null, closePopup: closePopup);
      return;
    }
    final error = data['error'];
    if (error is String && error.isNotEmpty) {
      finish(Exception(error), isError: true, closePopup: closePopup);
      return;
    }
    finish(sentState, closePopup: closePopup);
  }

  sub = html.window.onMessage.listen((event) async {
    // รับเฉพาะข้อความจากเว็บเดียวกัน (หน้า thaid_callback.html)
    if (event.origin != html.window.location.origin) return;
    final data = event.data;
    if (data is! Map || data['type'] != 'thaid') return;
    // ค่าสุ่มที่ได้กลับมาต้องตรงกับที่ส่งไป ไม่งั้นเป็นผลของคำขออื่น ไม่รับ
    if (data['state'] != sentState) {
      finish(
        Exception('ค่าตรวจสอบไม่ตรงกับที่ส่งไป กรุณายืนยันตัวตนใหม่'),
        isError: true,
        closePopup: false,
      );
      return;
    }
    handleResult(data, closePopup: false);
  });

  // ผลจากหน้า callback แท็บใหม่ (มือถือ) ส่งมาทุกแท็บของเว็บนี้ รับเฉพาะ state ของคำขอนี้
  // state ไม่ตรง = คำขอของแท็บอื่น ข้ามไปเฉย ๆ
  try {
    channel = html.BroadcastChannel(thaidChannelName);
    channelSub = channel.onMessage.listen((dynamic event) {
      final data = event.data;
      if (data is! Map || data['type'] != 'thaid') return;
      if (data['state'] != sentState) return;
      handleResult(data);
    });
  } catch (_) {
    // เบราว์เซอร์เก่าที่ไม่มี BroadcastChannel ยังมีการถามสถานะข้างล่าง
  }

  // ถามสถานะจาก backend (ทางของมือถือ ที่ผลไม่ได้กลับมาทาง postMessage)
  // [cancelIfPending] = ถามครั้งสุดท้ายหลังหน้าต่าง ThaID ปิด: ยังไม่เสร็จ/ถามไม่ได้ = ผู้ใช้ยกเลิก
  var checking = false;
  Future<void> check({bool cancelIfPending = false}) async {
    if (done.isCompleted || checking) return;
    checking = true;
    try {
      final status = await api.thaidStatus(sentState);
      if (status == 'DONE' || status == 'ERROR') {
        finish(sentState);
      } else if (status == 'GONE' || cancelIfPending) {
        finish(null);
      }
    } finally {
      checking = false;
    }
  }

  bool pageVisible() => html.document.visibilityState != 'hidden';

  // ถามทั้งตอนหน้านี้แสดงและอยู่เบื้องหลัง: บนมือถือผู้ใช้อยู่ที่แท็บ callback ตอนผลออก
  // หน้านี้ต้องรู้ผลเพื่อปิดแท็บ ThaID ก่อนผู้ใช้สลับแท็บ (เบราว์เซอร์อาจถามช้าลงตอนอยู่เบื้องหลัง)
  poller = Timer.periodic(const Duration(seconds: 3), (_) => check());
  // มือถือหยุดตัวจับเวลาของแท็บที่อยู่เบื้องหลัง ถามทันทีเมื่อผู้ใช้กลับมาที่แท็บนี้
  visibility = html.document.onVisibilityChange.listen((_) {
    if (pageVisible()) check();
  });

  // หน้าต่าง ThaID ปิดแล้ว (ผู้ใช้ปิดเอง หรือมือถือปิดแท็บตอนเปิดแอป ThaID)
  // ถามสถานะครั้งสุดท้ายเมื่อหน้านี้แสดงอยู่ (ผู้ใช้อยู่ที่หน้านี้จริง) — เสร็จแล้วไปต่อ ยังไม่เสร็จ = ยกเลิก
  // รอเผื่อข้อความที่ส่งมาก่อนหน้าต่างปิดอีกนิด; ระหว่างผู้ใช้อยู่ในแอป ThaID (หน้านี้ซ่อน) ยังไม่ตัดสิน
  var popupClosedAt = 0;
  watcher = Timer.periodic(const Duration(seconds: 1), (_) {
    if (popup.closed != true) return;
    popupClosedAt++;
    if (popupClosedAt >= 2 && pageVisible()) check(cancelIfPending: true);
  });

  return done.future.timeout(
    const Duration(minutes: 11),
    onTimeout: () {
      stopListening();
      popup.close();
      throw Exception('หมดเวลายืนยันตัวตน กรุณาลองใหม่');
    },
  );
}
