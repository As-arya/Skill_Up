"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("@prisma/client");
const adapter_better_sqlite3_1 = require("@prisma/adapter-better-sqlite3");
const node_path_1 = __importDefault(require("node:path"));
// Resolve the SQLite database file path (relative to project root, same as prisma.config.ts)
const dbPath = node_path_1.default.join(process.cwd(), "dev.db");
// Prisma 7: Must use a driver adapter for database connections
const adapter = new adapter_better_sqlite3_1.PrismaBetterSqlite3({ url: `file:${dbPath}` });
// Prevent multiple Prisma Client instances in development (hot reload)
const globalForPrisma = globalThis;
exports.prisma = globalForPrisma.prisma || new client_1.PrismaClient({ adapter });
if (process.env.NODE_ENV !== "production") {
    globalForPrisma.prisma = exports.prisma;
}
