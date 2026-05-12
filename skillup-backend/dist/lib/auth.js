"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashPassword = hashPassword;
exports.verifyPassword = verifyPassword;
exports.signToken = signToken;
exports.verifyToken = verifyToken;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const JWT_SECRET = process.env.JWT_SECRET || "skillup-jwt-secret-dev-2026";
const SALT_ROUNDS = 10;
/**
 * Hash a plaintext password using bcryptjs.
 */
async function hashPassword(password) {
    return bcryptjs_1.default.hash(password, SALT_ROUNDS);
}
/**
 * Verify a plaintext password against a bcrypt hash.
 */
async function verifyPassword(password, hash) {
    return bcryptjs_1.default.compare(password, hash);
}
/**
 * Sign a JWT token with user payload.
 * Token expires in 7 days by default.
 */
function signToken(payload) {
    return jsonwebtoken_1.default.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
/**
 * Verify and decode a JWT token.
 * Returns the decoded payload or null if invalid.
 */
function verifyToken(token) {
    try {
        return jsonwebtoken_1.default.verify(token, JWT_SECRET);
    }
    catch {
        return null;
    }
}
