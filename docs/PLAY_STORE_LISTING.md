# Draf Listing Play Store — SIA-PDAM Lapangan

> Aplikasi internal petugas (bukan untuk publik umum). Pertimbangkan **Internal
> testing / Closed testing track** atau distribusi terbatas. Sesuaikan teks
> dengan kebijakan PDAM Anda.

## Identitas
- **Nama aplikasi:** SIA-PDAM Lapangan
- **Application ID:** `id.web.pdamcore.sia_pdam_field`
- **Kategori:** Bisnis / Peralatan (Tools)
- **Kontak developer:** (email & website PDAM)

## Deskripsi singkat (≤ 80 karakter)
> Pencatatan baca meter air untuk petugas lapangan PDAM — offline-first.

## Deskripsi lengkap (≤ 4000 karakter)
```
SIA-PDAM Lapangan adalah aplikasi resmi untuk petugas pembaca meter air PDAM.
Dirancang offline-first agar tetap bisa bekerja di lokasi tanpa sinyal.

Fitur:
• Masuk aman dengan akun petugas (token, penyimpanan terenkripsi).
• Unduh daftar tugas per periode lalu bekerja sepenuhnya offline.
• Catat angka meter, opsi estimasi bila meter tak terbaca.
• Ambil foto meter sebagai bukti pembacaan.
• Sinkronisasi otomatis saat sinyal kembali — aman dari duplikasi.
• Penanda status: sudah dibaca, antri, tersinkron, dan peringatan anomali.

Aplikasi ini ditujukan untuk penggunaan internal petugas PDAM yang telah
memiliki akun. Bukan untuk pelanggan umum.
```

## Aset grafis yang harus disiapkan
| Aset | Ukuran | Status |
|---|---|---|
| Ikon aplikasi | 512×512 PNG | ✅ `docs/store/icon-512.png` |
| Feature graphic | 1024×500 PNG | ✅ `docs/store/feature-graphic.png` |
| Screenshot ponsel | min 2 (mis. layar Login & Tugas) | ambil dari emulator |

Privacy Policy: draf di `docs/PRIVACY_POLICY.md` — isi placeholder & publikasikan ke URL publik.

> Screenshot bisa diambil: `adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png`.

## Data Safety (form wajib Google Play)
- **Data dikumpulkan:** email/identitas petugas (untuk autentikasi), foto meter
  (untuk bukti pembacaan), data bacaan meter.
- **Tujuan:** fungsionalitas aplikasi (operasional baca-meter).
- **Enkripsi saat transit:** Ya (HTTPS).
- **Token disimpan terenkripsi** di perangkat (Keychain/Keystore).
- **Tidak ada iklan**, tidak dibagikan ke pihak ketiga.
- **Privacy Policy:** WAJIB ada URL kebijakan privasi (siapkan halaman di situs PDAM).

## Content rating
Kuesioner: aplikasi bisnis/utility, tanpa konten sensitif → rating "Everyone".

## Rilis
- Unggah **`.aab`** (`flutter build appbundle --release`, ter-tandatangani).
- Aktifkan **Play App Signing**.
- Mulai dari **Internal testing**, tambahkan email penguji, naikkan ke produksi
  setelah backend `pdamcore.web.id` ter-deploy & login terverifikasi.

## Checklist pra-submit
- [ ] Backend field API sudah live (lihat `DEPLOY_BACKEND.md`)
- [ ] `key.properties` + keystore siap; `flutter build appbundle --release` OK
- [ ] Privacy Policy URL aktif
- [ ] Screenshot + feature graphic siap
- [ ] Data Safety diisi sesuai di atas
- [ ] Versi dinaikkan di `pubspec.yaml` (`version: x.y.z+build`)
