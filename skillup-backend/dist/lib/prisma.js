"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("@prisma/client");
const adapter_pg_1 = require("@prisma/adapter-pg");
const pg_1 = require("pg");
// Railway/Production: Always use PostgreSQL.
// DATABASE_URL must be set in Railway environment variables.
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
    console.error("[FATAL] DATABASE_URL environment variable is not set!");
    console.error("[FATAL] Available env keys:", Object.keys(process.env).filter(k => k.startsWith("DATA") || k.startsWith("NODE") || k.startsWith("PORT")).join(", "));
    process.exit(1);
}
const pool = new pg_1.Pool({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false },
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
});
const adapter = new adapter_pg_1.PrismaPg(pool);
exports.prisma = new client_1.PrismaClient({ adapter });
