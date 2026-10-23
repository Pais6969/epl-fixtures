# EPL Fixtures

Aplikasi mobile Flutter untuk melihat **jadwal, hasil, dan klasemen Premier League (Liga Inggris)**.
Data diambil langsung dari REST API [football-data.org](https://www.football-data.org/) (v4).

> Dibuat untuk UTS Pemrograman Mobile – Praktikum Mobile Programming G.

## Deskripsi singkat

EPL Fixtures membantu penggemar sepak bola memantau pertandingan Premier League dalam satu aplikasi:
jadwal per pekan, skor pertandingan yang sudah selesai, detail pertandingan, dan tabel klasemen.
Data bersifat dinamis (diambil dari API), bukan data statis di dalam kode.

## Fitur utama

- **Jadwal pertandingan per pekan (matchday)**, dikelompokkan per tanggal, lengkap dengan logo klub, jam kick-off, dan skor.
- **Navigasi pekan**: tombol sebelumnya/berikutnya atau pilih langsung dari daftar pekan. Aplikasi otomatis membuka pekan yang sedang berjalan.
- **Filter status pertandingan**: Semua, Akan main, Berlangsung, Selesai.
- **Detail pertandingan**: skor akhir, skor babak pertama, hasil, tanggal, jam, dan wasit.
- **Klasemen**: posisi, main, menang, seri, kalah, selisih gol, dan poin, dengan penanda zona 4 besar dan degradasi.
- **Penanganan asinkron dengan `FutureBuilder`**: tampilan *loading*, *success*, dan *error* (termasuk tombol "Coba lagi").

## Teknologi dan package

| Teknologi / package | Fungsi |
|---|---|
| Flutter & Dart | Framework dan bahasa pemrograman |
| `http` | Mengirim permintaan HTTP ke API |
| `intl` | Format tanggal dan jam berbahasa Indonesia |
| `google_fonts` | Font Barlow dan Barlow Condensed |
| `flutter_svg` | Menampilkan logo klub berformat SVG |

## Struktur folder

```
lib/
├── main.dart                     # Titik masuk aplikasi
├── config/api_config.dart        # URL dasar API & pembacaan token
├── theme/app_theme.dart          # Warna dan tema
├── models/                       # Class model (JSON -> objek Dart)
│   ├── team_model.dart
│   ├── match_model.dart
│   └── standing_model.dart
├── services/
│   └── football_api_service.dart # Permintaan HTTP & penanganan error
├── pages/
│   ├── home_page.dart            # Navigasi bawah (Jadwal / Klasemen)
│   ├── fixtures_page.dart        # Jadwal + FutureBuilder
│   ├── match_detail_page.dart    # Detail pertandingan
│   └── standings_page.dart       # Klasemen + FutureBuilder
└── widgets/                      # Komponen UI yang dipakai ulang
```

## Langkah menjalankan aplikasi

1. Pastikan Flutter sudah terpasang (`flutter doctor`).
2. Daftar gratis di <https://www.football-data.org/client/register>, lalu salin **API token** dari email atau halaman akun.
3. Clone repository ini:
   ```bash
   git clone https://github.com/Pais69/epl-fixtures.git
   cd utsprak
   flutter pub get
   ```
4. Jalankan di emulator Android atau perangkat fisik dengan token milikmu:
   ```bash
   flutter run --dart-define=FOOTBALL_DATA_TOKEN=TOKEN_KAMU
   ```
   Di Android Studio: *Run > Edit Configurations > Additional run args* lalu isi
   `--dart-define=FOOTBALL_DATA_TOKEN=TOKEN_KAMU`.

> Token sengaja tidak disimpan di repository agar aman. Tanpa token, aplikasi menampilkan pesan error yang menjelaskan cara mengisinya.

## Catatan

- Paket gratis football-data.org dibatasi 10 permintaan per menit dan skor bersifat tertunda (bukan live real-time).
- Jalankan di Android/iOS, bukan di browser (Chrome), karena API dapat menolak permintaan lintas-origin (CORS).
