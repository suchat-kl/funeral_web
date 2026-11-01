import 'package:flutter/material.dart';

/// ชี้เมาส์แล้วลอยขึ้นและขยายเล็กน้อย เอาเมาส์ออกกลับที่เดิม
///
/// [builder] ได้ค่า hovered ไปเปลี่ยนเงา/สีขอบของการ์ดให้เข้ากับการลอยได้เอง
/// บนจอสัมผัสไม่มีการชี้เมาส์ การ์ดจึงอยู่นิ่งตามปกติ
class HoverLift extends StatefulWidget {
  final Widget Function(bool hovered) builder;

  /// ระยะที่ลอยขึ้น (จุด)
  final double lift;

  /// อัตราขยายตอนชี้
  final double scale;

  const HoverLift({
    super.key,
    required this.builder,
    this.lift = 6,
    this.scale = 1.04,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // t วิ่ง 0 -> 1 ตอนชี้ และ 1 -> 0 ตอนออก ใช้ทั้งระยะลอยและอัตราขยาย
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _hovered ? 1 : 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -widget.lift * t),
          child: Transform.scale(
            scale: 1 + (widget.scale - 1) * t,
            child: child,
          ),
        ),
        child: widget.builder(_hovered),
      ),
    );
  }
}
