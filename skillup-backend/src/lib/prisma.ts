import { PrismaClient } from "@prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";
import * as path from "node:path";

function createAdapter() {
  if (process.env.NODE_ENV === "production") {
    // Production: PostgreSQL (Supabase / Render)
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });
    return new PrismaPg(pool);
  } else {
    // Development: SQLite local file
    const dbPath = path.join(process.cwd(), "dev.db");
    return new PrismaBetterSqlite3({ url: `file:${dbPath}` });
  }
}

// Prevent multiple Prisma Client instances in development (hot reload)
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma || new PrismaClient({ adapter: createAdapter() });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
