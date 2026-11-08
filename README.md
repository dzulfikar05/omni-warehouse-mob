# omni_warehouse_mob

## Getting Started

### Konfigurasi API

Salin `.env.example.json` menjadi `.env.json`, lalu sesuaikan `API_BASE_URL`.
Untuk Android Emulator, gunakan `http://10.0.2.2/api`; untuk perangkat fisik,
gunakan alamat IP komputer server yang dapat dijangkau perangkat, misalnya
`http://192.168.1.10/api`.

Jalankan aplikasi dengan:

```sh
flutter run --dart-define-from-file=.env.json
```

Gunakan flag yang sama saat build, misalnya:

```sh
flutter build apk --dart-define-from-file=.env.json
```

File `.env.json` tidak disimpan di Git. Pastikan setiap environment memiliki
file konfigurasi sendiri sebelum menjalankan atau membuild aplikasi.
