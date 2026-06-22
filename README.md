# SIA-PDAM Lapangan (Field Client)

Client mobile **offline-first** untuk petugas baca meter SIA-PDAM.
Mengikuti kontrak resmi **SIA-PDAM Field API v1** (`/api/v1/field`).

Backend: Laravel 13 · Base URL prod: `https://pdamcore.web.id/api/v1/field`

---

## Fitur (sesuai kontrak)

- 🔐 Login token (Bearer, TTL 12 jam) → disimpan di **secure storage** (Keychain / Keystore / EncryptedSharedPreferences), bukan plaintext.
- ⏱️ Rate-limit login → countdown di UI.
- 📅 Pilih periode terbuka (`GET /periods`).
- 📋 Unduh & cache tugas (`GET /assignments`) ke **local DB (sqflite)** untuk dipakai offline.
- 📝 Input bacaan offline (UUID v4 per entry), opsi **estimasi** (kirim `null`).
- 📷 Foto meter (kamera/galeri) dengan pra-validasi ≤5 MB & JPEG/PNG.
- 🔄 **Sync batch idempoten** (`POST /readings/sync`, max 500/batch, paginate otomatis).
- ⬆️ Upload foto (`POST /readings/{id}/photo`) hanya setelah `reading_id` tersedia.
- ⚠️ Tampilkan status per item: tersinkron / antri / galat / **anomali**.
- 🚪 `401` mana pun → auto-logout + redirect login.

Semua angka meter/uang diperlakukan sebagai **string** (mis. `"1234.00"`), tidak pernah `number`.

---

## Struktur

```
lib/
  core/        config, api_client (Dio), api_exception, token_store (secure)
  data/        app_database (sqflite), auth_repository, field_repository, sync_service
  models/      user, period, assignment, reading_entry, sync_result
  state/       auth_provider, field_provider (Provider/ChangeNotifier)
  ui/          login_screen, home_screen, reading_entry_screen
  main.dart    dependency wiring + router berbasis status auth
test/          sync_payload_test.dart
```

Alur sync mengikuti pola local-DB wajib di skill: ambil entry `synced=false`
→ batch → proses per status (`recorded` / `already_synced` / `error`) → retry aman.

---

## Menjalankan

> Mesin ini belum punya Flutter SDK. Setelah SDK terpasang:

```bash
# 1. Generate scaffolding platform (TIDAK menimpa lib/ yang sudah ada)
flutter create . --org id.web.pdamcore --project-name sia_pdam_field

# 2. Ambil dependency
flutter pub get

# 3. Jalankan tes unit (tanpa device)
flutter test

# 4. Jalankan di device/emulator
flutter run
```

### Izin platform yang perlu ditambahkan setelah `flutter create`

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Untuk memfoto meter air.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Untuk memilih foto meter.</string>
```

---

## Konfigurasi

Lihat `lib/core/config.dart`:
- `useProd` → `true` (prod) / `false` (arahkan ke `baseUrlDev`).
- Ubah `baseUrlDev` ke host pengujian internal Anda.

---

## Catatan kontrak (v1)

- Estimasi & deteksi anomali **server-side** — client tidak menduplikasi logika.
- Satu foto per bacaan (upload ulang menimpa).
- Belum ada delta-sync / riwayat bacaan.
- Idempotensi sync dijamin kunci alami `(connection_id, period_id)`.
