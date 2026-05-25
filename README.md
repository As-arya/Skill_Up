# SkillUp

## 1. App Name

**SkillUp**

## 2. Deskripsi Singkat

SkillUp adalah aplikasi AI-powered career readiness platform yang membantu pengguna mengevaluasi kesiapan karier mereka. Aplikasi ini menyediakan fitur untuk menganalisis CV, mencocokkan skill dengan target role, mengevaluasi portfolio, mengelola daftar skill, mengelola project, dan memantau learning target.

Secara arsitektur, SkillUp menggunakan pola client-server dengan Flutter sebagai frontend, Express.js sebagai backend REST API, Prisma sebagai ORM, PostgreSQL sebagai database, serta integrasi AI eksternal melalui Groq dan Gemini.

## 3. Tech Stack

### Frontend

- Flutter
- Dart
- Material UI
- HTTP Client
- File Picker
- Syncfusion PDF
- Flutter Secure Storage
- Shared Preferences
- Local Notifications

### Backend

- Node.js
- Express.js
- TypeScript
- Prisma ORM
- PostgreSQL
- JWT Authentication
- bcryptjs
- CORS

### AI & External Services

- Groq API
- Gemini API
- Jina Reader / r.jina.ai
- GitHub README Fetch

### Deployment

- Flutter APK
- Firebase App Distribution
- Railway
- Neon PostgreSQL

## 4. Software Architecture

![SkillUp Software Architecture](readme-assets/software-architecture.png)

## 5. Project Setup

### Prerequisites

Pastikan sudah menginstall:

- Flutter SDK
- Node.js
- npm
- PostgreSQL database atau Neon PostgreSQL
- Groq API key
- Gemini API key

### Backend Setup

Masuk ke folder backend:

```bash
cd skillup-backend
```

Install dependency:

```bash
npm install
```

Buat file `.env` berdasarkan `.env.example`:

```bash
cp .env.example .env
```

Isi environment variable berikut:

```env
GROQ_API_KEY=your_groq_api_key
GEMINI_API_KEY=your_gemini_api_key
JWT_SECRET=your_jwt_secret
DATABASE_URL="postgresql://USER:PASSWORD@HOST/neondb?sslmode=require"
```

Generate Prisma client:

```bash
npx prisma generate
```

Jalankan migration database:

```bash
npx prisma migrate deploy
```

Untuk development lokal, bisa menggunakan:

```bash
npx prisma migrate dev
```

Jalankan backend:

```bash
npm run dev
```

Backend berjalan di:

```text
http://localhost:3000
```

Health check:

```text
http://localhost:3000/health
```

### Frontend Setup

Masuk ke folder frontend:

```bash
cd skillup-frontend
```

Install dependency Flutter:

```bash
flutter pub get
```

Jalankan aplikasi:

```bash
flutter run
```

Secara default, frontend menggunakan API base URL:

```text
http://10.0.2.2:3000/api
```

URL tersebut digunakan untuk Android Emulator agar dapat mengakses backend lokal di komputer host.

Jika ingin menggunakan backend production, jalankan Flutter dengan `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend-url/api
```

### Build APK

Untuk membuat APK release:

```bash
cd skillup-frontend
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-url/api
```

Output APK berada di:

```text
skillup-frontend/build/app/outputs/flutter-apk/app-release.apk
```

### Database Check

Untuk membuka database secara visual:

```bash
cd skillup-backend
npx prisma studio
```

Untuk mengecek status migration:

```bash
npx prisma migrate status
```
