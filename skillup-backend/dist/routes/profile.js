"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../lib/prisma");
const auth_1 = require("../middlewares/auth");
const router = (0, express_1.Router)();
router.get('/', auth_1.requireAuth, async (req, res) => {
    try {
        const userId = Number(req.query.userId);
        if (!userId || isNaN(userId)) {
            res.status(400).json({ error: 'Valid userId query parameter is required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        const user = await prisma_1.prisma.user.findUnique({
            where: { id: userId },
            select: {
                id: true,
                name: true,
                email: true,
                university: true,
                createdAt: true,
            },
        });
        if (!user) {
            res.status(404).json({ error: 'User not found' });
            return;
        }
        res.status(200).json({ user });
    }
    catch (error) {
        console.error('Profile GET Error:', error);
        res.status(500).json({ error: 'Failed to fetch profile.' });
    }
});
exports.default = router;
