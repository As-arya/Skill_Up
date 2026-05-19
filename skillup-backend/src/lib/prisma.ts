import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";

// Production: always use PostgreSQL via DATABASE_URL
// Local dev: set DATABASE_URL to empty or don't set it, use `npm run dev` with SQLite separately
const databaseUrl = process.env.DATABASE_URL || "";

let adapter: any;

if (databaseUrl.startsWith("postgresql://") || databaseUrl.startsWith("postgres://")) {
  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false },
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  });
  adapter = new PrismaPg(pool);
} else {
  // Local dev fallback: SQLite
  const { PrismaBetterSqlite3 } = require("@prisma/adapter-better-sqlite3");
  const path = require("node:path");
  const dbPath = path.join(process.cwd(), "dev.db");
  adapter = new PrismaBetterSqlite3({ url: `file:${dbPath}` });
}

// Prevent multiple Prisma Client instances in development (hot reload)
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma || new PrismaClient({ adapter });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
