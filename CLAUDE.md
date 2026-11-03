# funeral_web — ระบบดาวน์โหลดไฟล์และใบเสร็จฌาปนกิจ (Flutter Web)

หน้าเว็บของระบบดาวน์โหลดไฟล์และใบเสร็จฌาปนกิจ กรมทางหลวง แทนระบบเดิม Java JSF
สมาชิกฌาปนกิจดาวน์โหลดใบเสร็จรับเงินของตัวเอง ทุกคนดาวน์โหลดแบบฟอร์ม ผู้ที่เข้าสู่ระบบดาวน์โหลดทะเบียนคุมรายชื่อ
เจ้าหน้าที่นำไฟล์เข้าและดูรายงานฌาปนกิจจากระบบหักหนี้ ผู้ดูแลจัดการผู้ใช้ ลายเซ็น และข้อมูลเดิม

**repo นี้เป็น Public** — ห้ามมีค่าลับ ข้อมูลบุคคลจริง (ชื่อ เลขบัตร เลขสมาชิก) หรือเอกสารออกแบบภายใน
ข้อกำหนดหลักอยู่นอก repo (ห้าม commit / ห้ามคัดลอกเข้ามา) ค่าตั้งทั้งหมดอยู่ฝั่ง backend

## ที่มาของโค้ด

โครงแอป (แถบบน เมนูข้าง ธีม) ส่วนเข้าสู่ระบบ / refresh token / ThaID / 2FA / passkey
**ยกมาจากหน้าเว็บสลิปภาษี** (`C:\AI\flutter\sliptax` ซึ่งยกจาก HTC อีกที) เมื่อ 1 พ.ย. 2569
ตาราง/หน้ารายงานยกแบบจากหน้าเว็บหักหนี้ (`C:\AI\flutter\dpay`: `sheet_table.dart`, `work_parts.dart`, `chapana_slip_screen.dart`)
ส่วนที่เป็นของสลิปภาษี (กลุ่ม doh/hwp, สิทธิ์รายหน้าจอ, รายงานภาษี/สลิป ฯลฯ) ตัดออกหมดแล้ว

## โครงสร้างระบบ

| ส่วน | ที่อยู่ |
|---|---|
| หน้าเว็บ (repo นี้, Public) | `C:\AI\flutter\funeral` → github `suchat-kl/funeral_web` |
| Backend Spring Boot + MongoDB (Private) | `C:\AI\springboot\funeral` → github `suchat-kl/spr_funeral` |

API endpoint เลือกตอน run/build ด้วย `--dart-define=API_BASE=...` (ดู `ApiService.baseUrl`)
- ไม่ส่งมา = production `https://backupdoh.doh.go.th/funeralapi`
- development = `https://suchat-dev.doh.go.th/funeralapi` (nginx บน WSL ต้องมี `127.0.0.1 suchat-dev.doh.go.th` ใน hosts ของ Windows)

หน้าเว็บวางใต้ path `/funeral/` (`<base href>` ใน `web/index.html`) — `https://inf.doh.go.th/funeral/` โดเมนเดียวกับสลิปภาษีและหักหนี้

## คำสั่งที่ใช้ประจำ

```bash
flutter run -d chrome --dart-define=API_BASE=https://suchat-dev.doh.go.th/funeralapi   # dev ชี้ WSL
flutter build web --no-wasm-dry-run            # build production → build/web (release เท่านั้น ไม่ต้องใส่ API_BASE)
flutter analyze                                # ต้องไม่มี issue
flutter test                                   # ห้ามใส่ --platform chrome (ค้างไม่มีกำหนด)
bash tool/check_logging.sh                     # ตรวจว่าไม่มี print/debugPrint และทุก AppLogger ครอบด้วย if (AppLogger.on)
dart format lib test
```

VS Code: Run and Debug → `funeral dev (WSL API)` (พอร์ต 5575) / `funeral dev (production API - ข้อมูลจริง)` (พอร์ต 5576)
พอร์ตไม่ชนกับ HTC (5555/5556) และสลิปภาษี (5565/5566)

**ห้าม** build ขึ้น production ด้วย `--debug` หรือ `--profile` — log จะไม่ถูก tree-shake
`--base-href` ถ้าต้องส่ง ให้รันจาก PowerShell (Git Bash แปลงค่าที่ขึ้นต้นด้วย `/` เป็น path ของ Windows)

## ผังโค้ด (`lib/`)

```
main.dart     โครงแอป: MaterialApp + แถบบน + เมนูข้าง (ตรึงได้) + บังคับเปลี่ยนรหัสผ่าน + กลับหน้าแรกเมื่อออกจากระบบ
config/       app_config.dart (ชื่อระบบ, ชื่อที่เก็บในเบราว์เซอร์), theme.dart (6 ธีม)
models/       stored_file (ไฟล์แบบฟอร์ม/ทะเบียนคุม), register_ticket (ใบผ่านลงทะเบียน), receipt (งวดใบเสร็จ, ผลค้นสมาชิก,
              PdfPassword), user_admin (ผู้ใช้/บทบาท/หน้าของผลค้น), uploader, signature, import_result, stats,
              two_factor (challenge ของ login, ข้อมูลตั้งค่า 2FA), passkey
providers/    auth_provider.dart — สถานะ session, access (MenuAccess), เข้าสู่ระบบทุกแบบ
services/     api_service.dart (Dio ทุก endpoint + ErrorCodes), auth_interceptor.dart (แนบ JWT / 401 → refresh แล้วยิงซ้ำ)
screens/      home (หน้าแรก), general_files / monthyear_files (ดาวน์โหลด), receipt_period / cash_receipt (ใบเสร็จ),
              upload_files (นำไฟล์เข้า หน้าเดียวรับ kind), chapana_slip (rep9) / chapana_retired (rep10),
              admin_users / admin_uploaders / admin_signatures / admin_import (ผู้ดูแล)
widgets/      app_menu (รายการเมนูทั้งระบบ + เงื่อนไขเห็น), sidebar_menu, header, footer, account_actions (ทางเข้าร่วมของงานบัญชี),
              login_dialog, register_dialog, forgot_password_dialog, change_password_dialog, two_factor_dialog, qr_view,
              passkey_dialog, passkey_unavailable_dialog, account_form (ช่อง/กติการหัสผ่าน/ปุ่ม/โครงหน้าต่าง),
              file_table (ตารางไฟล์ + ค้นหา + แบ่งหน้า), upload_file_dialog (+ FileForChips), user_admin_dialog,
              pdf_password_picker, work_parts (WorkPage, FactRow, MonthYearPicker, FileDownloads, DownloadButtons, LoadState),
              screen_parts, sheet_table, app_pagination, thai_date_picker, test_phase_banner
utils/        roles.dart (Roles, MenuAccess, PersonType, FileFor), util.dart (วันที่ไทย, เลขบัตรแบบปิด, ขนาดไฟล์),
              thaid.dart (เปิด ThaID + รอผล รวมกรณีมือถือแท็บใหม่), passkey*.dart (WebAuthn), file_pick.dart, file_download.dart,
              logger.dart, dialog.dart, snackbar_helper.dart, base64url.dart
```

หน้าจอใหม่: เพิ่มไฟล์ใน `screens/` เพิ่มเมธอดใน `ApiService` (ใช้ `_authedRequest` / `_download` / `_multipart` ซึ่งต่ออายุ token ให้)
แล้วเพิ่มรายการใน `buildAppMenu()` พร้อมเงื่อนไขใน `MenuAccess`

## บทบาทและเมนู

backend ส่ง `roles[]` เป็นชื่อสั้น: `NON_MEMBER` หรือ `MEMBER` (อย่างใดอย่างหนึ่ง ระบบตั้งเองทุกครั้งที่เข้าสู่ระบบ),
`UPLOADER` (มีชื่อในรายชื่อผู้มีสิทธิ์นำไฟล์เข้า), `ADMIN` (ได้ UPLOADER ด้วยเสมอ แต่ไม่ได้ MEMBER)
**เก็บเป็นรายการข้อความ ไม่ใช่ enum ปิด** (`Roles.listFrom`) — จะมีบทบาทเพิ่ม (เจ้าหน้าที่ฝากเงินล่วงหน้า) บทบาทที่ไม่รู้จักแสดงรหัสเดิม

| เมนู (`AppMenuItem.id`) | ไม่ login | ไม่ใช่สมาชิก | สมาชิก | ผู้นำไฟล์เข้า | ผู้ดูแล |
|---|---|---|---|---|---|
| ดาวน์โหลด › แบบฟอร์มทั่วไป `general-files` | ✔ | ✔ | ✔ | ✔ | ✔ |
| ดาวน์โหลด › ทะเบียนคุมรายชื่อ `monthyear-files` | | ✔ | ✔ | ✔ | ✔ |
| ดาวน์โหลด › ใบเสร็จรับเงิน (รายงวด) `receipt-period` | | | ✔ | เฉพาะที่เป็นสมาชิก | เฉพาะที่เป็นสมาชิก |
| ดาวน์โหลด › ใบเสร็จรับเงิน (เงินสด) `receipt-cash` | | | ของตัวเอง | ทุกคน | ทุกคน |
| นำไฟล์เข้า › แบบฟอร์มทั่วไป / ทะเบียนคุมรายชื่อ | | | | ✔ | ✔ |
| รายงาน › ฌาปนกิจ-สลิป / ผู้เกษียณในรายการฌาปนกิจ | | | | ✔ | ✔ |
| ผู้ดูแล › ผู้ใช้ / ผู้มีสิทธิ์นำไฟล์เข้า / ลายเซ็นใบเสร็จ / นำเข้าข้อมูลเดิม | | | | | ✔ |
| บัญชี › ลงทะเบียน / ลืมรหัสผ่าน | ✔ | | | | |
| บัญชี › เปลี่ยนรหัสผ่าน / ยืนยันตัวตนสองขั้น / ลายนิ้วมือ (เมื่อเบราว์เซอร์รองรับ) | | ✔ | ✔ | ✔ | ✔ |

เงื่อนไขทั้งหมดอยู่ที่ `MenuAccess` (`utils/roles.dart`) ใช้ร่วมกันทั้งเมนูข้าง เมนูผู้ใช้บนแถบบน — backend ตรวจสิทธิ์ซ้ำทุกเส้น

## เข้าสู่ระบบและบัญชี

- **รหัสผ่าน** → ถ้า `two_factor_required` ได้ `challenge` (ยังไม่เข้าสู่ระบบ) → `/api/auth/login/2fa`
  401 `TWO_FACTOR_CODE_WRONG` กรอกใหม่ด้วย challenge เดิม / 400 `TWO_FACTOR_REJECTED` กลับขั้นแรก
- **ThaID** (`thaidAuthorize` เปิดหน้าต่าง → `thaid_callback.html` ส่ง state กลับ / มือถือถาม `GET public-thaid/status` เป็นระยะ
  และฟัง BroadcastChannel `funeral_thaid`) → `public-thaid/login` ไม่ถาม 2FA ยังไม่ลงทะเบียน = 404 `NOT_REGISTERED` ชวนลงทะเบียน
- **passkey** → `public/passkey/options` ส่ง `username` ที่พิมพ์ไว้ (ถ้ามี) → `credential` ส่งเป็น**ข้อความ JSON**
  RP ID `inf.doh.go.th` ใช้ร่วมกับสลิปภาษี ชื่อ passkey ฝั่ง backend ขึ้นต้น "ฌาปนกิจ: "
- **ลงทะเบียน** (`RegisterDialog`) ขั้น 1 เป็นสมาชิก/ไม่เป็นสมาชิก → ขั้น 2 (สมาชิก: แบบเดิม เลขบัตร+เลขสมาชิก+วันเกิดจากปฏิทิน พ.ศ.
  ส่ง ค.ศ. yyyy-MM-dd หรือ ThaID mode=MEMBER / ไม่เป็นสมาชิก: ThaID mode=NON_MEMBER) → ใบผ่าน → ขั้น 3 ชื่อผู้ใช้+รหัสผ่าน
  `ALREADY_REGISTERED` = ปุ่มไปลืมรหัสผ่าน, `NOT_MEMBER` = ปุ่มลงทะเบียนแบบไม่เป็นสมาชิก, `DUPLICATE` (409) = เตือนที่ช่องชื่อผู้ใช้ใบผ่านเดิมใช้ต่อ,
  `REGISTER_TICKET_INVALID` = เริ่มขั้น 1 ใหม่, อื่น ๆ แสดง `message`
- **ลืมรหัสผ่าน** (`ForgotPasswordDialog`) ให้ตั้งรหัสใหม่และตรวจกติกา**ก่อน**สแกน ThaID เพราะ state ใช้ได้ครั้งเดียว
  (backend ใช้ผลทิ้งก่อนตรวจรหัส) สำเร็จแล้วอ่านชื่อผู้ใช้จากข้อความของ backend เติมในหน้าเข้าสู่ระบบ
- **2FA ของตัวเอง**: เปิด = รหัสผ่านปัจจุบัน → QR สร้างในเครื่องจาก `otpauth_uri` (`QrView`, package `qr` Dart ล้วน
  **ห้ามส่ง uri/secret ไปบริการภายนอก**) → รหัส 6 หลัก; ปิด = รหัสผ่าน + รหัส 6 หลัก (มือถือหาย = ผู้ดูแลปิดให้)
- **passkey ของตัวเอง**: เพิ่มต้องยืนยันรหัสผ่านทุก session บัญชีละไม่เกิน 5
- **บังคับเปลี่ยนรหัสผ่าน** เมื่อ `must_change_password` (ผู้ดูแลตั้งรหัสให้) หน้าต่างปิดไม่ได้ เลือกเปลี่ยนหรือออกจากระบบ
- ออกจากระบบ (ทุกทาง รวม refresh ไม่สำเร็จ) = กลับหน้าแรกและปิดหน้าจอที่เปิดค้าง; ส่ง access token ใน header + refresh token ใน body

## สัญญากับ backend ที่หน้าเว็บพึ่งอยู่

- ข้อผิดพลาดทุกเส้นรูป `{code, message, success:false}` — แสดง `message` (ภาษาไทยอยู่แล้ว) แยกกรณีด้วย `code` (`ErrorCodes`)
- 401 = token ใช้ไม่ได้ (interceptor ต่ออายุแล้วยิงซ้ำ) / 403 = บทบาทไม่พอ หรือ `PASSWORD_CHANGE_REQUIRED` (ไม่ต่ออายุ)
- `GET /api/public/general-files` แนบ token เมื่อเข้าสู่ระบบ (backend กรองตามประเภทบุคลากร: ไม่ login = "ทั้งหมด",
  G = ข้าราชการ+ทั้งหมด, E = ลูกจ้างประจำ+ทั้งหมด, ผู้นำไฟล์เข้า/ผู้ดูแล = ทุกไฟล์)
- ดาวน์โหลดไฟล์/PDF: ชื่อไฟล์จาก `Content-Disposition` (`filename*=UTF-8''` รองรับชื่อไทย) ข้อผิดพลาดมาเป็นไบต์ ถอดเป็น JSON
- นำไฟล์เข้า: multipart `file, typeFile?, title, fileFor, yearMonth?` (pdf doc docx xls xlsx zip ≤ 20 MB) แก้ด้วย PUT JSON
- ใบเสร็จรายงวด: `receiptNos[]` ≤ 24 งวด; ใบเสร็จเงินสด: `year` พ.ศ. + `months[]`, `memberNo` ส่งเฉพาะผู้นำไฟล์เข้า/ผู้ดูแล
  รหัสเปิดไฟล์ `passwordType` none/idcard/birthdate/custom (`password` เฉพาะ custom 4–32 ตัว) ออกให้ผู้อื่นใช้ได้แค่ none/custom
- รายงาน rep9/rep10 ส่ง `month` 2 หลัก + `year` พ.ศ. (+ `type` G/E ของ rep9) ผลมาจากระบบหักหนี้ 503 `DPAY_API_NOT_CONFIGURED` / 404 = แสดงข้อความ
- ลายเซ็น: multipart `kind, name, positionLines` (ส่งซ้ำได้หลายค่า), `effectiveFrom` "ปี พ.ศ.-เดือน", `file` JPEG/PNG ≤ 2 MB

## ข้อกำหนดเฉพาะโปรเจกต์

**Logging** ใช้ `AppLogger` เท่านั้น (ห้าม `print()` / `debugPrint()`) ทุกจุดครอบด้วย `if (AppLogger.on)` ค่าที่อ่อนไหวผ่าน `AppLogger.redact`
**ห้าม log** token, รหัสผ่าน, challenge, ticket, state ของ ThaID, เลขบัตร, ชื่อ, วันเกิด, credential ของ passkey
ไม่ใช้ `LogInterceptor` ของ Dio (พิมพ์ URI ที่มี query อ่อนไหว)

**ที่เก็บในเบราว์เซอร์** โดเมนเดียวกับสลิปภาษีและหักหนี้ คีย์ต้องไม่ชน
- token/session: flutter_secure_storage `WebOptions(dbName: 'FuneralEncryptedStorage', publicKey: 'FuneralSecureStorage')` ห้ามเอาออก
- localStorage: `funeral_theme`, `funeral_menu_pinned` (ทุกคีย์ขึ้นต้น `funeral_` ดู `AppConfig`)

**ป้ายช่วงทดสอบ** เอาออกแล้วเมื่อเปิดใช้จริง 3 พ.ย. 2569 (ไฟล์เดิมดูได้ในประวัติ git `lib/widgets/test_phase_banner.dart`)

**ฟอนต์ไทย** ระบุ `fontFamily` ชัดเสมอ (`NotoSansThai`, `Sarabun`, `Kanit` bundle มาแล้ว) — `screenText()` / `kAccountFont`

**วันที่** แสดงแบบ "28 ตุลาคม 2569" (`Util.formatThaiDate`, `Util.thaiDateOf` สำหรับข้อความเวลาจาก backend)
เลือกวันที่ด้วย `showThaiDatePicker` เท่านั้น **ห้ามเรียก `showDatePicker` ตรง ๆ** (แสดงปี ค.ศ.) ส่ง backend ด้วย `Util.isoDate` (ค.ศ.)
ปี-เดือนของ backend เป็น "ปี พ.ศ.-เดือน 2 หลัก" (`Util.yearMonth`) เลือกด้วย `YearStepper` + `MonthPicker` (ชื่อเดือนไทย)

**ตัวแบ่งหน้า** ใช้ `AppPagination` ทุกจุด (5/10/15/20 แถว ปุ่มเลขหน้า 5 ปุ่ม + หน้าแรก/สุดท้าย)
**มือถือ** ห้ามใช้ตัวเลือกที่ต้องกด Ctrl/Shift — เลือกหลายรายการด้วยปุ่มกดสลับ (งวดใบเสร็จ เดือน)
**ข้อมูลบุคคลบนจอ** เลขบัตรแสดงแบบปิดบางส่วน (`Util.maskIdcard`) ผลรายงาน/ผู้ใช้อยู่ในหน่วยความจำของหน้าจอเท่านั้น
**ภาษา** ข้อความที่ผู้ใช้เห็นและคอมเมนต์เป็นภาษาไทย

**ที่ว่างสำหรับอนาคต** หน้าแรกมี `_AdvanceDepositSlot` ไว้แสดงการ์ด "ยอดเงินฝากล่วงหน้า" ของสมาชิก (ยังไม่มีเส้น API ห้ามใส่ข้อมูลสมมุติ)

## เทสต์ (`test/`)

รันด้วย `flutter test` ธรรมดา — **ห้ามใส่ `--platform chrome`**
- `fake_backend.dart` — backend จำลอง (HttpClientAdapter ของ Dio ทั้งสองตัว ทดสอบ interceptor ตัวจริง) **ข้อมูลสมมุติทั้งหมด**
  บัญชี `admin1` / `upload1` (สมาชิก+ผู้นำไฟล์เข้า) / `member1` / `nonmember1` / `otpuser1` (เปิด 2FA) / `newbie1` (ต้องเปลี่ยนรหัส)
  ThaID จำลองด้วย `thaid[state] = FakeThaid(purpose, idcard)`, ทะเบียนสมาชิก `ffdMembers`, DPIS `dpis`, `birthDates`,
  `failures['METHOD path'] = (status, code, message)` บังคับให้เส้นใดตอบผิดพลาด, `calls` / `bodyOf` / `queryOf` / `authOf`
  `fakeIdcard('12 หลัก')` สร้างเลขบัตรสมมุติที่ผ่านหลักตรวจสอบ
- `helpers.dart` — `loginAs` (ผ่าน `tester.runAsync`), `installFakeSaver` (แทน Blob ดาวน์โหลด), `installFakeThaid`, `installFakePasskey`,
  `loadAppFonts` (ฟอนต์จริง ไม่งั้นวัดความกว้างผิด), `useDesktopView`
- `login_test` (รหัสผ่าน 2FA ThaID passkey บังคับเปลี่ยนรหัส ออกจากระบบ หน้าแรก), `register_test` (3 ทาง + ทุก code),
  `menu_test` (MenuAccess + เมนูข้างทุกบทบาท), `receipt_test`, `files_test` (ดาวน์โหลด/นำไฟล์เข้า),
  `admin_report_test` (ผู้ดูแล + rep9/rep10), `account_test` (2FA QR, passkey, เปลี่ยน/ลืมรหัสผ่าน, ฟังก์ชันช่วย),
  `mobile_layout_test` (จอ 375 กว้าง ต้องไม่ล้น)

## Git

remote `https://github.com/suchat-kl/funeral_web.git` (Public) — commit message ภาษาไทยแบบ Conventional Commits
เช่น `feat(receipt): หน้าใบเสร็จรายงวด` ทำงานบน branch แล้ว merge เข้า `main` ตรวจ `git status` ก่อน commit ทุกครั้ง
