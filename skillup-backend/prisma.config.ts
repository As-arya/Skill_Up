// Prisma 7 configuration file
// - Local dev: SQLite (dev.db)
// - Production: PostgreSQL via DATABASE_URL env var
import "dotenv/config";
import { defineConfig, env } from "prisma/config";
import * as path from "node:path";

const isProduction = process.env.NODE_ENV === "production";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: isProduction
      ? env("DATABASE_URL")
      : `file:${path.join(process.cwd(), "dev.db")}`,
  },
});
