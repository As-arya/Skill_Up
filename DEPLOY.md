# SkillUp — Panduan Deploy

**Arsitektur production (semua gratis, tanpa kartu kredit):**
```
Neon PostgreSQL  ←→  Render Web Service (Express)  ←→  Flutter APK
                                                              ↑
                                              Firebase App Distribution
```

---

## BAGIAN A — SIAPKAN DATABASE NEON

### A1. Buat tabel di Neon

Pastikan `DATABASE_URL` di `skillup-backend/.env` sudah diisi dengan connection string Neon.

Jalankan migration dari folder `skillup-backend`:
```bash
NODE_ENV=production npx tsx scripts/migrate-prod.ts
```

Output yang diharapkan:
```
🔄 Running production migration...
✅ Migration complete.
```

Semua tabel (User, Skill, Project, ProjectLink, LearningTarget) sudah terbuat di Neon.

---

## BAGIAN B — DEPLOY BACKEND KE RENDER

### B1. Push code ke GitHub

```bash
git add .
git commit -m "chore: prepare for production deployment"
git push origin main
```

> **Penting:** Pastikan `.env` tidak ikut ter-push (sudah ada di `.gitignore`).

---

### B2. Buat akun Render

1. Buka [render.com](https://render.com) → **Get Started for Free**
2. Sign up dengan **GitHub** (lebih mudah karena bisa auto-connect repo)
3. Tidak perlu kartu kredit untuk Web Service

---

### B3. Buat Web Service di Render

1. Di Render dashboard → **New → Web Service**
2. Connect GitHub → pilih repository `SkillUp-2-main`
3. Konfigurasi:
   - **Name:** `skillup-backend`
   - **Root Directory:** `skillup-backend`
   - **Runtime:** `Node`
   - **Region:** `Singapore (Southeast Asia)`
   - **Branch:** `main`
   - **Build Command:** *(biarkan kosong — otomatis dari `render.yaml`)*
   - **Start Command:** *(biarkan kosong — otomatis dari `render.yaml`)*
   - **Plan:** `Free`

4. Scroll ke **Environment Variables** → klik **Add Environment Variable** untuk setiap baris:

   | Key | Value |
   |-----|-------|
   | `NODE_ENV` | `production` |
   | `DATABASE_URL` | connection string Neon kamu |
   | `JWT_SECRET` | string random panjang, contoh: `skillup-prod-2026-xK9mP3qR7vL2nW8` |
   | `GEMINI_API_KEY` | API key dari [aistudio.google.com](https://aistudio.google.com/app/apikey) |
   | `GROQ_API_KEY` | API key dari [console.groq.com](https://console.groq.com) |

5. Klik **Create Web Service**
6. Tunggu build selesai (~3-5 menit) — lihat progress di tab **Logs**

---

### B4. Verifikasi Backend

Setelah deploy, Render memberikan URL seperti:
```
https://skillup-backend.onrender.com
```

Test health:
```
https://skillup-backend.onrender.com/health
```
Harus return: `{"status":"ok"}`

Test register:
```bash
curl -X POST https://skillup-backend.onrender.com/api/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@example.com","password":"test1234"}'
```
Harus return token JWT.

**Catat URL ini** — dipakai saat build Flutter.

---

## BAGIAN C — BUILD & DISTRIBUSI APK VIA FIREBASE

### C1. Buat Firebase Project

1. Buka [console.firebase.google.com](https://console.firebase.google.com)
2. **Add project** → nama: `SkillUp` → disable Analytics → **Create project**

---

### C2. Tambahkan Android App

1. Klik icon **Android**
2. **Android package name:** cek di `skillup-frontend/android/app/build.gradle`
   ```
   applicationId "com.example.skillup"
   ```
3. **App nickname:** `SkillUp Android`
4. Klik **Register app**
5. **Download `google-services.json`**
6. Letakkan di: `skillup-frontend/android/app/google-services.json`
7. Klik **Next → Next → Continue to console**

---

### C3. Aktifkan App Distribution

1. Firebase Console → menu kiri → **App Distribution**
2. Klik **Get started** → pilih app Android

---

### C4. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

---

### C5. Build APK Production

Dari folder `skillup-frontend`:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://skillup-backend.onrender.com/api
```

> Ganti URL dengan URL Render kamu dari langkah B4.

APK ada di:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

### C6. Upload APK ke Firebase

Dapatkan App ID dari Firebase Console → **Project Settings → Your apps → App ID**
Format: `1:123456789012:android:abcdef1234567890`

```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:123456789012:android:abcdef1234567890 \
  --release-notes "SkillUp v1.0 - Initial release"
```

Atau upload manual di Firebase Console → App Distribution → Upload.

---

## CHECKLIST

### Database & Backend
- [ ] `NODE_ENV=production npx tsx scripts/migrate-prod.ts` → `✅ Migration complete`
- [ ] Code sudah di-push ke GitHub (tanpa `.env`)
- [ ] Render Web Service sudah dibuat dengan 5 env vars
- [ ] `https://[url].onrender.com/health` → `{"status":"ok"}`
- [ ] Register via curl berhasil dapat token

### Flutter & Firebase
- [ ] `google-services.json` ada di `android/app/`
- [ ] APK berhasil di-build dengan `--dart-define=API_BASE_URL=...`
- [ ] APK di-upload ke Firebase App Distribution
- [ ] Login dari APK berhasil

---

## TROUBLESHOOTING

**Render build gagal — `prisma generate` error:**
Pastikan `NODE_ENV=production` ada di env vars Render.

**APK tidak bisa konek — connection timeout:**
Render free tier sleep setelah 15 menit idle. Request pertama butuh ~30-50 detik.
Solusi gratis: daftar [UptimeRobot](https://uptimerobot.com) → monitor `https://[url].onrender.com/health` setiap 5 menit.

**Neon connection error di production:**
Pastikan `DATABASE_URL` di Render env vars menggunakan format pooler Neon:
```
postgresql://...@ep-xxx-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
```
