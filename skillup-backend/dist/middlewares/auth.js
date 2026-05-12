"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = void 0;
const auth_1 = require("../lib/auth");
const requireAuth = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
        return;
    }
    const token = authHeader.split(' ')[1];
    const decoded = (0, auth_1.verifyToken)(token);
    if (!decoded) {
        res.status(401).json({ error: 'Unauthorized: Invalid token' });
        return;
    }
    req.user = decoded;
    next();
};
exports.requireAuth = requireAuth;
