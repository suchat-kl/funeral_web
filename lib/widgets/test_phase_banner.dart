import 'package:flutter/material.dart';

/// ป้ายแจ้งว่าระบบอยู่ในช่วงทดสอบ แสดงเหนือทุกหน้าจอ (ใส่ไว้ใน MaterialApp.builder)
/// เปิดใช้งานจริงแล้วให้เอา TestPhaseBanner ออกจาก main.dart
class TestPhaseBanner extends StatelessWidget {
  const TestPhaseBanner({super.key});

  static const String message = 'ระบบงานอยู่ในช่วงทดสอบการใช้ระบบ';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3CD),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0B94A))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 18, color: Color(0xFF7A5200)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A5200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
