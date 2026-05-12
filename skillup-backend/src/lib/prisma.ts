import { PrismaClient } from "@prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import path from "node:path";

// Resolve the SQLite database file path (relative to project root, same as prisma.config.ts)
const dbPath = path.join(process.cwd(), "dev.db");

// Prisma 7: Must use a driver adapter for database connections
const adapter = new PrismaBetterSqlite3({ url: `file:${dbPath}` });

// Prevent multiple Prisma Client instances in development (hot reload)
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient({ adapter });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
