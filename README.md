# SkillUp 🚀

SkillUp is an AI-powered platform designed to help software engineers evaluate their job readiness, identify skill gaps, and optimize their portfolios.

## Features
- **AI CV Checker**: Get constructive feedback on your CV.
- **Skill Matching**: Compare your current skills against specific job descriptions.
- **Portfolio Evaluation**: Analyze your web portfolio for industry standards.
- **Project Management**: Showcase your projects with automatic GitHub README tag extraction.

---

## 🛠 Setup Instructions

### 1. Backend (Express.js + Prisma)
Located in `skillup-backend/`

1.  **Install dependencies**:
    ```bash
    cd skillup-backend
    npm install
    ```
2.  **Environment Variables**:
    - Copy `.env.example` to `.env`
    - Fill in your `GEMINI_API_KEY` and `GROQ_API_KEY`.
3.  **Database Setup**:
    ```bash
    npx prisma migrate dev --name init
    npx prisma generate
    ```
4.  **Run the server**:
    ```bash
    npm run dev
    ```

### 2. Frontend (Flutter)
Located in `skillup-frontend/`

1.  **Install dependencies**:
    ```bash
    cd skillup-frontend
    flutter pub get
    ```
2.  **API Configuration**:
    - Ensure the backend is running.
    - If running on an Android Emulator, the app uses `10.0.2.2:3000` to connect to localhost.
3.  **Run the app**:
    ```bash
    flutter run
    ```

---

## 🔒 Security Note
Do **NOT** commit your `.env` files. They are already listed in `.gitignore`. Ensure you provide your own API keys for the AI features to work.
