#!/usr/bin/env bash
# ตรวจว่าไม่มี debugPrint / print หลุดกลับเข้ามาใน lib/
#
# `avoid_print` ใน analysis_options.yaml ดักได้แค่ print() แต่ดัก debugPrint ไม่ได้
# สคริปต์นี้ปิดช่องว่างนั้น ใช้รันใน CI หรือ pre-commit hook
#
#   bash tool/check_logging.sh
set -uo pipefail

cd "$(dirname "$0")/.."

fail=0

hits=$(grep -rn "debugPrint(" lib --include="*.dart" | grep -v "^lib/main.dart:" || true)
if [ -n "$hits" ]; then
  echo "พบ debugPrint( ที่ยังไม่ได้แปลงเป็น AppLogger:"
  echo "$hits"
  fail=1
fi

# Perm.print(...) ใน permission.dart เป็นชื่อเมธอดตรวจสิทธิ์พิมพ์ ไม่ใช่การ log จึงข้ามบรรทัดประกาศนั้น
hits=$(grep -rnE "(^|[^a-zA-Z0-9_.])print\(" lib --include="*.dart" | grep -v "static bool print(String screenCode)" || true)
if [ -n "$hits" ]; then
  echo "พบ print( ใน lib/ — ให้ใช้ AppLogger แทน:"
  echo "$hits"
  fail=1
fi

# call site ของ AppLogger ต้องครอบด้วย `if (AppLogger.on)` เสมอ
# ไม่งั้น dart2js จะเก็บ string literal ไว้ใน main.dart.js ถึงแม้จะไม่พิมพ์ออกมา
# บรรทัดก่อนหน้าที่เป็น `if (AppLogger.on) {` ถือว่าครอบแล้ว (call แบบหลายบรรทัด)
hits=$(find lib -name "*.dart" ! -path "lib/utils/logger.dart" -print0 \
       | xargs -0 awk '
           /^[[:space:]]*AppLogger\.(d|i|w|e|lazy)\(/ &&
           prev !~ /^[[:space:]]*if \(AppLogger\.on\) \{[[:space:]]*$/ {
             printf "%s:%d: %s\n", FILENAME, FNR, $0
           }
           { prev = $0 }
         ' || true)
if [ -n "$hits" ]; then
  echo "พบ AppLogger ที่ไม่ได้ครอบด้วย if (AppLogger.on) — ข้อความจะติดไปกับ bundle:"
  echo "$hits"
  fail=1
fi

# LogInterceptor ต้องไม่เปิด header/body ทิ้งไว้ (token และ PII จะโผล่ใน console)
hits=$(grep -rnE "(requestHeader|responseBody|requestBody|responseHeader): true" lib --include="*.dart" || true)
if [ -n "$hits" ]; then
  echo "LogInterceptor เปิด header/body ไว้ — เสี่ยง token รั่ว:"
  echo "$hits"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "ตรวจ logging ผ่าน ไม่พบ debugPrint/print ที่ไม่ควรมี"
fi
exit "$fail"
