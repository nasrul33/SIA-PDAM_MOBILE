# Runbook: Deploy Field API ke produksi (`pdamcore.web.id`)

> Prasyarat agar **SIA-PDAM Lapangan** (client mobile) berfungsi. Saat ini
> `pdamcore.web.id` menjalankan build lama **tanpa** route `/api/v1/field/*`
> (semua `404`). Kode field API sudah ada di repo backend (`D:\SIA-PDAM`,
> remote `nasrul33/SIA-PDAM2`) — tinggal di-deploy.
>
> Dijalankan oleh admin server (butuh SSH/panel hosting). Client tidak perlu
> diubah: ia sudah memanggil `https://pdamcore.web.id/api/v1/field`.

## 0. Verifikasi cepat masalahnya
```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://pdamcore.web.id/api/v1/field/auth/login \
  -H "Accept: application/json" -d '{}'
# 404 = field API belum ter-deploy (yang sedang kita perbaiki)
# 422 = sudah ter-deploy (validasi jalan) → selesai
```

## 1. Ambil kode terbaru
```bash
cd /path/ke/sia-pdam        # root Laravel di server
php artisan down            # maintenance mode
git fetch origin && git checkout main && git pull
composer install --no-dev --optimize-autoloader
```

## 2. Migrasi database
Field API menambah tabel `field_sessions` & `meter_routes`.
```bash
php artisan migrate --force
```
Pastikan `.env` produksi benar: `DB_CONNECTION=pgsql`, kredensial valid,
`APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://pdamcore.web.id`.

## 3. Object storage untuk foto meter
`POST /readings/{id}/photo` menyimpan ke disk `FILESYSTEM_DISK` (S3/MinIO).
Pastikan storage hidup & kredensial benar (`AWS_*` / `AWS_ENDPOINT`, bucket ada).
Jika pakai disk `local`, jalankan `php artisan storage:link`.

## 4. Refresh cache & restart
```bash
php artisan config:cache
php artisan route:cache
php artisan event:cache
# restart worker/opcache sesuai setup (php-fpm reload, supervisor, dll.)
php artisan up
```

## 5. Data minimum agar petugas bisa kerja
- Minimal satu akun aktif role **`petugas_meter`** (login pakai email + password).
- Minimal satu **periode terbuka** (belum dikunci) → muncul di `GET /periods`.
- **Penugasan/route** berisi `connections` untuk petugas itu → muncul di
  `GET /assignments`. (Tanpa ini, daftar tugas kosong — itu normal, bukan bug.)

## 6. Verifikasi pasca-deploy (dari mana saja)
```bash
# login → harus 200 + token
curl -s -X POST https://pdamcore.web.id/api/v1/field/auth/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"email":"<petugas>","password":"<sandi>"}'

# periods tanpa token → harus 401 (bukan 404)
curl -s -o /dev/null -w "%{http_code}\n" \
  https://pdamcore.web.id/api/v1/field/periods -H "Accept: application/json"
```
Lalu buka app → login → harus masuk ke "Tugas Baca Meter".

## Rollback
```bash
php artisan down
git checkout <commit-sebelumnya>
composer install --no-dev --optimize-autoloader
php artisan migrate:rollback --step=2   # field_sessions + meter_routes (hati-hati)
php artisan config:cache route:cache && php artisan up
```

## Kontrak (acuan)
Enduan endpoint (semua di bawah `/api/v1/field`): `POST auth/login`,
`POST auth/logout`, `GET periods`, `GET assignments?period_id=`,
`POST readings/sync`, `POST readings/{id}/photo`. Token Bearer, TTL 12 jam.
Detail: skill `sia-pdam-field-api`.
