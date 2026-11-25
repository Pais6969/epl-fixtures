# Perubahan dari UTS ke UAS — EPL Fixtures

Catatan ini menjadi bahan bab "Perubahan dari UTS ke UAS" pada laporan.

## 1. Ringkasan

| Aspek | UTS (v1.0) | UAS (v2.0) |
|---|---|---|
| Jumlah tab navigasi | 2 (Jadwal, Klasemen) | 4 (Jadwal, Klasemen, Statistik, Saya) |
| Halaman | Jadwal, Detail, Klasemen | + Profil Klub, Statistik, Saya, Pencarian Klub |
| Sumber data | football-data.org | football-data.org + Open-Meteo (cuaca) + GPS & geocoder perangkat |
| Endpoint API | `/matches`, `/standings` | + `/teams/{id}`, `/scorers` |
| Penyimpanan lokal | Tidak ada | Cache respons API + pengaturan (SharedPreferences) |
| Notifikasi | Tidak ada | Pengingat kick-off manual & otomatis klub favorit |
| Lokasi | Hanya konversi jam UTC ke waktu perangkat | Lokasi GPS pengguna, lokasi stadion (geocoding), jarak, Google Maps |
| Offline | Error "Tidak ada koneksi" | Data terakhir tetap tampil + pita "Mode offline" |
| Tema | Terang saja | Terang / Gelap / Ikuti sistem |
| Package | 4 | 10 (+6) |

## 2. Fitur baru

| No | Fitur | Letak | Keterangan |
|---|---|---|---|
| 1 | Profil klub | Halaman baru `ClubPage` (dibuka dari klasemen, detail laga, pencarian, statistik) | Stadion, alamat, berdiri, warna klub, pelatih, situs resmi, performa 5 laga terakhir (M/S/K), laga berikutnya, hasil terakhir, skuad |
| 2 | Klub favorit | Tombol ⭐ di profil klub / pencarian / tab Saya | Ditandai bintang & garis kuning di kartu jadwal, latar kuning di klasemen, filter "Klub favorit" di jadwal |
| 3 | Notifikasi pengingat kick-off | Tombol "Ingatkan saya" di detail laga; pengaturan di tab Saya | 15/30/60 menit sebelum kick-off. Otomatis untuk laga klub favorit dalam 14 hari. Isi notifikasi memuat prakiraan cuaca stadion. Ada tombol "Kirim notifikasi uji" |
| 4 | Lokasi GPS pengguna | Tab Saya > Lokasiku | Nama kota (reverse geocoding), koordinat, zona waktu, cuaca sekarang + saran nonton bareng. Jadwal menampilkan "Jam tayang di <kota>" |
| 5 | Stadion & cuaca saat kick-off | Detail pertandingan | Koordinat stadion dari alamat klub (geocoding), jam kick-off waktu setempat stadion, jarak dari kota pengguna, cuaca di stadion dan di kota pengguna saat kick-off, tombol Buka di Google Maps |
| 6 | Statistik | Tab baru Statistik | Top Skor (API) dan Statistik Klub: total laga & gol, lini serang, pertahanan, rata-rata poin, kemenangan (grafik batang) |
| 7 | Cache & mode offline | Semua halaman data | Respons API disimpan; dipakai ulang selama masih segar (hemat kuota 10 request/menit) dan ditampilkan saat offline |
| 8 | Pencarian klub | Ikon 🔍 di Jadwal & Klasemen | Cari berdasarkan nama/singkatan |
| 9 | Mode gelap | Tab Saya > Tampilan | Sistem / Terang / Gelap, tersimpan di perangkat |

## 3. Perubahan pada kode yang sudah ada

| Berkas | Perubahan |
|---|---|
| `main.dart` | Memuat pengaturan & inisialisasi notifikasi sebelum `runApp`; `MaterialApp` memakai `theme`, `darkTheme`, `themeMode` dan dibungkus `ListenableBuilder` |
| `theme/app_theme.dart` | Tema gelap, class `Palette` + extension `context.palette` agar warna menyesuaikan mode |
| `services/football_api_service.dart` | Lapisan cache (`_getCached`) dengan masa segar per data, parameter `force` untuk tombol muat ulang, `offlineSince` (ValueNotifier) untuk pita offline, `ApiException.statusCode`, method `fetchTeam` & `fetchScorers`, objek bersama `FootballApiService.shared` |
| `pages/home_page.dart` | 4 tab |
| `pages/fixtures_page.dart` | Filter "Klub favorit", tombol cari, pita offline, keterangan zona waktu & kota, sinkronisasi pengingat favorit setelah data dimuat, kartu bertanda favorit/pengingat |
| `pages/match_detail_page.dart` | Menjadi `StatefulWidget`; tombol pengingat; kartu Stadion & cuaca; logo klub bisa diketuk ke profil klub |
| `pages/standings_page.dart` | Baris bisa diketuk ke profil klub, penanda klub favorit, tombol cari, pita offline |
| `widgets/*` | Warna mengikuti mode gelap; `MatchCard` punya tanda favorit & pengingat; widget baru `SectionCard`, `InfoRow`, `OfflineBanner`, `WeatherSummary` |
| `AndroidManifest.xml` | Izin lokasi & notifikasi, receiver notifikasi terjadwal, query `https` untuk url_launcher, label aplikasi "EPL Fixtures" |
| `android/app/build.gradle.kts` | Core library desugaring (wajib untuk flutter_local_notifications) |
| `pubspec.yaml` | Versi 2.0.0, 6 package baru |

## 4. Berkas baru

- `models/`: `team_detail_model.dart`, `scorer_model.dart`, `weather_model.dart`, `user_location.dart`
- `services/`: `cache_store.dart`, `settings_service.dart`, `location_service.dart`, `weather_service.dart`, `notification_service.dart`
- `pages/`: `club_page.dart`, `stats_page.dart`, `search_page.dart`, `me_page.dart`
- `widgets/common.dart`

## 5. API baru

| API | Endpoint | Dipakai untuk | Masa cache |
|---|---|---|---|
| football-data.org | `GET /teams/{id}` | Profil klub, alamat stadion | 1 hari |
| football-data.org | `GET /competitions/PL/scorers?limit=20` | Top Skor | 30 menit |
| Open-Meteo | `GET /v1/forecast?latitude&longitude&current&hourly&timezone=auto` | Cuaca sekarang & per jam (16 hari) | 15 menit (memori) |
| Geocoder perangkat (`geocoding`) | `placemarkFromCoordinates`, `locationFromAddress` | Nama kota pengguna, koordinat stadion | Koordinat stadion disimpan permanen |

Masa cache endpoint lama: jadwal 2 menit, klasemen 10 menit.

## 6. Skenario pengujian tambahan (untuk tabel pengujian)

| No | Skenario | Langkah | Hasil yang diharapkan |
|---|---|---|---|
| 10 | Profil klub | Ketuk klub di klasemen | Info klub, performa, laga berikutnya, skuad (atau keterangan tidak tersedia) |
| 11 | Klub favorit | Ketuk ⭐ di profil klub | Bintang kuning; laga klub ditandai di jadwal; filter "Klub favorit" muncul |
| 12 | Pengingat manual | Detail laga yang akan main > "Ingatkan saya" | Snackbar konfirmasi, ikon lonceng di kartu, muncul di daftar "Pengingat terjadwal" |
| 13 | Notifikasi uji | Saya > "Kirim notifikasi uji" | Notifikasi muncul di panel notifikasi |
| 14 | Lokasi GPS | Saya > "Gunakan lokasi saya" > izinkan | Nama kota, koordinat, zona waktu, cuaca sekarang tampil |
| 15 | Izin lokasi ditolak | Tolak izin lokasi | Pesan "Izin lokasi ditolak" |
| 16 | Stadion & cuaca | Buka detail laga dalam 16 hari ke depan | Nama stadion, jam setempat, jarak, cuaca stadion & kota pengguna |
| 17 | Statistik | Buka tab Statistik | Top Skor (atau keterangan paket berbayar) dan Statistik Klub dengan grafik batang |
| 18 | Mode offline | Muat data, matikan internet, ketuk muat ulang | Data lama tetap tampil dengan pita "Mode offline" |
| 19 | Pencarian | Ketik "ars" di pencarian | Hanya Arsenal yang tampil |
| 20 | Mode gelap | Saya > Tampilan > Gelap | Seluruh halaman berganti ke tema gelap |
| 21 | Pengaturan tersimpan | Tutup lalu buka aplikasi | Klub favorit, tema, lokasi, dan pengingat tetap tersimpan |
