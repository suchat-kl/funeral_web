import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

/// ส่วนท้ายหน้าแรก ยกโครงมาจากระบบ HTC เหลือเฉพาะชื่อระบบ กลุ่มผู้ใช้ และแถบลิขสิทธิ์
/// (ที่อยู่ เบอร์โทร ลิงก์ และช่องรับข่าวสารของระบบเดิมเป็นของศูนย์ฝึกอบรม ไม่ได้ยกมา)
class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;
        return Container(
          width: double.infinity,
          color: AppTheme.primaryColor,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: _buildBrand(isMobile: isMobile),
              ),
              _buildCopyrightBar(context),
            ],
          ),
        );
      },
    );
  }

  // Logo and Title
  Widget _buildBrand({bool isMobile = false}) {
    return Row(
      children: [
        Container(
          width: isMobile ? 40 : 50,
          height: isMobile ? 40 : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          // ไอคอนเดียวกับแถบบนของระบบ
          child: Icon(
            AppConfig.logoIcon,
            color: AppTheme.primaryColor,
            size: isMobile ? 24 : 30,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.systemName,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                AppConfig.orgName,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'สำหรับสมาชิกฌาปนกิจ ข้าราชการ และลูกจ้างประจำ กรมทางหลวง',
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบลิขสิทธิ์ — ปีเป็น พ.ศ. ของวันที่เปิดหน้า (ไม่ต้องแก้ทุกปี)
  /// ลิงก์ "นโยบายความเป็นส่วนตัว / ข้อกำหนดการใช้งาน" ของ HTC ไม่ได้ยกมา เพราะระบบนี้ยังไม่มีเอกสารสองฉบับนั้น
  /// (ลิงก์ที่กดแล้วไม่เกิดอะไรทำให้ผู้ใช้สับสน) มีเอกสารเมื่อใดค่อยเพิ่ม
  Widget _buildCopyrightBar(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'NotoSansThai',
      color: Colors.white70,
      fontSize: 12,
    );
    final buddhistYear = DateTime.now().year + 543;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2)),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text('© พ.ศ. $buddhistYear กรมทางหลวง', style: style),
          Text('•', style: style?.copyWith(color: Colors.white38)),
          Text('สงวนลิขสิทธิ์', style: style),
        ],
      ),
    );
  }
}
