import * as bcrypt from "bcryptjs";
import * as jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "skillup-jwt-secret-dev-2026";
const SALT_ROUNDS = 10;

/**
 * Hash a plaintext password using bcryptjs.
 */
export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

/**
 * Verify a plaintext password against a bcrypt hash.
 */
export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

/**
 * Sign a JWT token with user payload.
 * Token expires in 7 days by default.
 */
export function signToken(payload: {
  userId: number;
  email: string;
}): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}

/**
 * Verify and decode a JWT token.
 * Returns the decoded payload or null if invalid.
 */
export function verifyToken(
  token: string
): { userId: number; email: string } | null {
  try {
    return jwt.verify(token, JWT_SECRET) as {
      userId: number;
      email: string;
    };
  } catch {
    return null;
  }
}
