/**
 * Production migration script for PostgreSQL (Neon).
 * Runs during Railway build via: npx tsx scripts/migrate-prod.ts
 *
 * Creates all tables if they don't exist yet.
 * Safe to run multiple times (idempotent).
 */

import "dotenv/config";
import { Pool } from "pg";

const sql = `
CREATE SCHEMA IF NOT EXISTS "public";

CREATE TABLE IF NOT EXISTS "User" (
  "id"         SERIAL PRIMARY KEY,
  "name"       TEXT NOT NULL,
  "email"      TEXT NOT NULL UNIQUE,
  "password"   TEXT NOT NULL,
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "User" DROP COLUMN IF EXISTS "university";

CREATE TABLE IF NOT EXISTS "Skill" (
  "id"        SERIAL PRIMARY KEY,
  "userId"    INTEGER NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "name"      TEXT NOT NULL,
  "category"  TEXT NOT NULL,
  "isChecked" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE ("userId", "name")
);

CREATE TABLE IF NOT EXISTS "Project" (
  "id"          SERIAL PRIMARY KEY,
  "userId"      INTEGER NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "title"       TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "tags"        TEXT NOT NULL,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL
);

CREATE TABLE IF NOT EXISTS "ProjectLink" (
  "id"        SERIAL PRIMARY KEY,
  "projectId" INTEGER NOT NULL REFERENCES "Project"("id") ON DELETE CASCADE,
  "type"      TEXT NOT NULL,
  "url"       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS "LearningTarget" (
  "id"            SERIAL PRIMARY KEY,
  "userId"        INTEGER NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "skillName"     TEXT NOT NULL,
  "targetMinutes" INTEGER NOT NULL DEFAULT 30,
  "deadline"      TEXT,
  "isCompleted"   BOOLEAN NOT NULL DEFAULT false,
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
`;

async function main() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });

  try {
    console.log("🔄 Running production migration...");
    await pool.query(sql);
    console.log("✅ Migration complete.");
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error("❌ Migration failed:", e.message);
  process.exit(1);
});
