# 🧠 FedMind Mobile App
### *On-Device Multimodal Clinical Decision Support System (CDSS) for Depression Screening with Explainable AI (XAI)*

Aplikasi prototipe mobile CDSS berbasis **Flutter & ONNX Runtime** untuk skrining risiko depresi multimodal (*Teks MentalBERT, Visual Facial Action Units OpenFace, dan Prosodi Audio eGeMAPS/MFCC*) yang terintegrasi dengan atribusi klinis berbasis **Shapley Values (XAI)** dan rekam medis lokal SQLite.

---

## 📥 Unduh Langsung (*Direct Downloads*)

Saat ini prototipe **FedMind Mobile** hanya ditujukan untuk platform **Android (Android 13+ / ARM64 `arm64-v8a`)**. Anda dapat mengunduh langsung berkas APK melalui halaman [GitHub Releases](https://github.com/Pannavira/fedmind-mobile-app/releases):

| Platform | Format File | Tautan Unduhan Langsung | Petunjuk Pemasangan |
| :--- | :---: | :---: | :--- |
| **Android (13+)** | `.apk` | [**Unduh APK (Rilis Terbaru)**](https://github.com/Pannavira/fedmind-mobile-app/releases/latest/download/fedmind-app-release.apk) | Unduh di HP Android > Buka file > Izinkan *"Install from unknown sources"*. |

---

## 🚀 Panduan Pemasangan (Android)

1. Klik tautan [**Unduh APK**](https://github.com/Pannavira/fedmind-mobile-app/releases/latest/download/fedmind-app-release.apk) langsung dari browser HP Android Anda (minimum Android 13 / API 33 agar pipeline audio-speech dual-channel berjalan penuh).
2. Buka berkas yang telah diunduh (`fedmind-app-release.apk`).
3. Jika muncul notifikasi keamanan Google Play Protect / Chrome:
   - Pilih **Pengaturan (Settings)** > Aktifkan **Izinkan dari sumber ini (Allow from this source)**.
   - Ketuk **Instal (Install)**.
4. Buka aplikasi **FedMind** dan berikan izin sensor kamera serta mikrofon saat diminta untuk sesi observasi klinis.

---

## 🛠️ Fitur Utama Aplikasi

- **Triangulasi Sinyal Multimodal On-Device**:
  - Ekstraksi 75 dimensi visual (Aktivasi Action Units dahi, mata, senyuman, dan penurunan sudut bibir).
  - Ekstraksi 248 dimensi akustik (Kontur frekuensi dasar Pitch F0, Jitter, Shimmer, dan RMS Energy).
  - Ekstraksi 768 dimensi MentalBERT NLP (Deteksi leksikon afek emosional dan kata ganti reflektif).
- **Explainable AI (XAI) Interaktif**:
  - Neraca Shapley dinamis (*Teks vs Visual vs Audio*) dengan verifikasi klinisi (Format SOAP).
- **Simulasi & Benchmark E-DAIC (Sandbox)**:
  - Menguji kasus nyata dari dataset standar emas penelitian (*P600 Normal Reference* dan *P716 Severe Depression Reference*).

---

## 💻 Menjalankan dari Source Code (Development)

Jika ingin memodifikasi atau menjalankan secara lokal:

```bash
# 1. Clone repositori
git clone https://github.com/Pannavira/fedmind-mobile-app.git
cd fedmind-mobile-app

# 2. Ambil pustaka dependencies
flutter pub get

# 3. Jalankan unit test
flutter test

# 4. Jalankan aplikasi di emulator atau perangkat fisik
flutter run
```
