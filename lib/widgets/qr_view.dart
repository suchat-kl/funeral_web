import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// รูป QR ที่สร้างในเครื่องจากข้อความ [data] (package `qr` เป็น Dart ล้วน ไม่เรียกบริการภายนอก)
///
/// ใช้กับ otpauth_uri ของการตั้งค่า 2FA — **ห้าม**ส่งค่านี้ไปสร้าง QR ที่เว็บอื่น เพราะเป็นความลับของบัญชี
/// สร้างไม่ได้ (ข้อความยาวเกิน) แสดงข้อความให้ใช้รหัสตั้งค่าแทน
class QrView extends StatelessWidget {
  final String data;
  final double size;
  final String? semanticLabel;

  const QrView({
    super.key,
    required this.data,
    this.size = 200,
    this.semanticLabel,
  });

  /// เมทริกซ์ของ QR (จริง = จุดดำ) สร้างไม่ได้ = null
  static List<List<bool>>? matrixOf(String data) {
    if (data.isEmpty) return null;
    try {
      final image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
      return [
        for (var r = 0; r < image.moduleCount; r++)
          [for (var c = 0; c < image.moduleCount; c++) image.isDark(r, c)],
      ];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrix = matrixOf(data);
    if (matrix == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text(
            'แสดง QR ไม่ได้\nกรุณาใช้รหัสตั้งค่าด้านล่าง',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'NotoSansThai', fontSize: 13),
          ),
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _QrPainter(matrix)),
    );
  }
}

class _QrPainter extends CustomPainter {
  final List<List<bool>> matrix;

  _QrPainter(this.matrix);

  @override
  void paint(Canvas canvas, Size size) {
    // ขอบขาว 4 ช่องตามมาตรฐาน ให้แอปในมือถืออ่านง่าย
    const quiet = 4;
    final n = matrix.length + quiet * 2;
    final cell = size.width / n;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var r = 0; r < matrix.length; r++) {
      for (var c = 0; c < matrix.length; c++) {
        if (!matrix[r][c]) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (c + quiet) * cell,
            (r + quiet) * cell,
            cell + 0.5,
            cell + 0.5,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.matrix != matrix;
}
