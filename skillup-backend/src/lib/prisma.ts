import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";

// Railway/Production: Always use PostgreSQL.
// DATABASE_URL must be set in Railway environment variables.
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error("[FATAL] DATABASE_URL environment variable is not set!");
  console.error("[FATAL] Available env keys:", Object.keys(process.env).filter(k => k.startsWith("DATA") || k.startsWith("NODE") || k.startsWith("PORT")).join(", "));
  process.exit(1);
}

const pool = new Pool({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

const adapter = new PrismaPg(pool);

export const prisma = new PrismaClient({ adapter });
