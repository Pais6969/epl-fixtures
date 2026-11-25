# EPL Fixtures

Aplikasi mobile Flutter untuk melihat **jadwal, hasil, klasemen, dan statistik Premier League (Liga Inggris)**,
lengkap dengan **pengingat kick-off**, **info stadion + prakiraan cuaca**, dan **lokasi pengguna**.
Data sepak bola diambil dari REST API [football-data.org](https://www.football-data.org/) (v4),
data cuaca dari [Open-Meteo](https://open-meteo.com/).

> Dibuat untuk UTS dan dilanjutkan untuk UAS Pemrograman Mobile – Praktikum Mobile Programming G.

## Deskripsi singkat

EPL Fixtures membantu penggemar sepak bola memantau Premier League dalam satu aplikasi:
jadwal per pekan, skor, detail pertandingan, klasemen, profil klub, dan statistik.
Pengguna dapat memilih klub favorit agar laganya diingatkan lewat notifikasi, melihat cuaca di stadion
dan di kotanya sendiri saat kick-off, serta tetap melihat data terakhir saat offline.

## Fitur utama

### Fitur UTS
- **Jadwal pertandingan per pekan (matchday)**, dikelompokkan per tanggal, lengkap dengan logo klub, jam kick-off, dan skor.
- **Navigasi pekan** dan pembukaan otomatis pekan yang sedang berjalan.
- **Filter status pertandingan**: Semua, Akan main, Berlangsung, Selesai.
- **Detail pertandingan**: skor akhir, skor babak pertama, hasil, tanggal, jam, dan wasit.
- **Klasemen** dengan penanda zona Liga Champions, Europa League, dan degradasi.
- **Penanganan asinkron dengan `FutureBuilder`**: tampilan *loading*, *success*, dan *error*.

### Fitur baru UAS
- **Profil klub** (halaman baru): stadion, alamat, tahun berdiri, pelatih, performa 5 laga terakhir, laga berikutnya, dan skuad.
- **Statistik** (tab baru): Top Skor dari API dan Statistik Klub yang diolah dari klasemen (grafik batang).
- **Saya** (tab baru): lokasi GPS & cuaca di kota pengguna, klub favorit, pengaturan notifikasi, mode gelap, dan data offline.
- **Klub favorit**: ditandai di jadwal & klasemen, punya filter khusus, dan diingatkan otomatis.
- **Notifikasi pengingat kick-off** (15/30/60 menit sebelum), manual per laga maupun otomatis untuk klub favorit; isi notifikasi memuat prakiraan cuaca di stadion.
- **Lokasi dinamis**: lokasi GPS pengguna (jam tayang di kotanya, jarak ke stadion), koordinat stadion dari alamat klub (geocoding), dan tombol buka Google Maps.
- **Prakiraan cuaca saat kick-off** di stadion dan di kota pengguna (cerah, berawan, mendung, gerimis, hujan, badai, dll).
- **Cache & mode offline**: respons API disimpan di perangkat; bila koneksi gagal, data terakhir tetap tampil.
- **Pencarian klub** dan **mode gelap**.

## Teknologi dan package

| Teknologi / package | Fungsi |
|---|---|
| Flutter & Dart | Framework dan bahasa pemrograman |
| `http` | Mengirim permintaan HTTP ke API |
| `intl` | Format tanggal dan jam berbahasa Indonesia |
| `google_fonts` | Font Barlow dan Barlow Condensed |
| `flutter_svg` | Menampilkan logo klub berformat SVG |
| `shared_preferences` | **(UAS)** Cache data API dan penyimpanan pengaturan |
| `flutter_local_notifications` + `timezone` | **(UAS)** Notifikasi pengingat terjadwal |
| `geolocator` | **(UAS)** Lokasi GPS pengguna dan perhitungan jarak |
| `geocoding` | **(UAS)** Alamat ↔ koordinat (nama kota pengguna, lokasi stadion) |
| `url_launcher` | **(UAS)** Membuka Google Maps dan situs resmi klub |

## Struktur folder

```
lib/
├── main.dart                      # Titik masuk aplikasi (tema, pengaturan, notifikasi)
├── config/api_config.dart         # URL dasar API & pembacaan token
├── theme/app_theme.dart           # Tema terang & gelap, Palette
├── models/
│   ├── team_model.dart
│   ├── match_model.dart
│   ├── standing_model.dart
│   ├── team_detail_model.dart     # (UAS) detail klub, pelatih, skuad
│   ├── scorer_model.dart          # (UAS) pencetak gol
│   ├── weather_model.dart         # (UAS) prakiraan cuaca & kategori cuaca
│   └── user_location.dart         # (UAS) lokasi pengguna
├── services/
│   ├── football_api_service.dart  # Permintaan HTTP, cache, penanganan error
│   ├── cache_store.dart           # (UAS) cache SharedPreferences
│   ├── settings_service.dart      # (UAS) pengaturan pengguna (ChangeNotifier)
│   ├── location_service.dart      # (UAS) GPS & geocoding
│   ├── weather_service.dart       # (UAS) Open-Meteo
│   └── notification_service.dart  # (UAS) notifikasi & pengingat
├── pages/
│   ├── home_page.dart             # Navigasi bawah 4 tab
│   ├── fixtures_page.dart         # Jadwal
│   ├── match_detail_page.dart     # Detail + stadion & cuaca + pengingat
│   ├── standings_page.dart        # Klasemen
│   ├── club_page.dart             # (UAS) Profil klub
│   ├── stats_page.dart            # (UAS) Statistik
│   ├── search_page.dart           # (UAS) Pencarian klub
│   └── me_page.dart               # (UAS) Saya: lokasi, favorit, notifikasi, tema
└── widgets/                       # Komponen UI yang dipakai ulang
```

## Langkah menjalankan aplikasi

1. Pastikan Flutter sudah terpasang (`flutter doctor`).
2. Daftar gratis di <https://www.football-data.org/client/register>, lalu salin **API token**.
3. Clone repository ini:
   ```bash
   git clone https://github.com/Pais6969/epl-fixtures.git
   cd epl-fixtures
   flutter pub get
   ```
4. Jalankan di emulator Android atau perangkat fisik dengan token milikmu:
   ```bash
   flutter run --dart-define=FOOTBALL_DATA_TOKEN=TOKEN_KAMU
   ```
   Di Android Studio: *Run > Edit Configurations > Additional run args* lalu isi
   `--dart-define=FOOTBALL_DATA_TOKEN=TOKEN_KAMU`.

> Token sengaja tidak disimpan di repository agar aman.

## Izin aplikasi (Android)

| Izin | Untuk |
|---|---|
| `INTERNET` | Mengambil data API |
| `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` | Lokasi pengguna (diminta saat menekan "Gunakan lokasi saya") |
| `POST_NOTIFICATIONS` | Menampilkan notifikasi (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Menjadwalkan ulang pengingat setelah perangkat dinyalakan ulang |

## Catatan

- Paket gratis football-data.org dibatasi 10 permintaan per menit dan skor bersifat tertunda. Cache membantu menghemat permintaan.
- Sebagian data (pencetak gol, skuad) dapat termasuk paket berbayar; aplikasi menampilkan keterangan bila data tidak tersedia.
- Prakiraan cuaca hanya tersedia untuk laga dalam ±16 hari ke depan.
- Pengingat memakai alarm tidak-presisi Android (tanpa izin alarm khusus), jadi bisa bergeser beberapa menit.
- Jalankan di Android/iOS, bukan di browser, karena API dapat menolak permintaan lintas-origin (CORS).
