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
        const learningTargets = await prisma_1.prisma.learningTarget.findMany({
            where: { userId },
            orderBy: { createdAt: 'asc' },
        });
        res.status(200).json({ learningTargets });
    }
    catch (error) {
        console.error('Learning Targets GET Error:', error);
        res.status(500).json({ error: 'Failed to fetch learning targets.' });
    }
});
router.post('/', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, skillName, targetMinutes, deadline } = req.body;
        if (!userId || !skillName) {
            res.status(400).json({ error: 'userId and skillName are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        const learningTarget = await prisma_1.prisma.learningTarget.create({
            data: {
                userId,
                skillName,
                targetMinutes: targetMinutes || 30,
                deadline,
            },
        });
        res.status(201).json({ learningTarget });
    }
    catch (error) {
        console.error('Learning Target POST Error:', error);
        res.status(500).json({ error: 'Failed to create learning target.' });
    }
});
router.put('/:id/complete', auth_1.requireAuth, async (req, res) => {
    try {
        const id = Number(req.params.id);
        if (isNaN(id)) {
            res.status(400).json({ error: 'Invalid ID' });
            return;
        }
        const target = await prisma_1.prisma.learningTarget.findUnique({ where: { id } });
        if (!target) {
            res.status(404).json({ error: 'Learning target not found' });
            return;
        }
        if (target.userId !== req.user?.userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        const updatedTarget = await prisma_1.prisma.learningTarget.update({
            where: { id },
            data: { isCompleted: true },
        });
        res.status(200).json({ learningTarget: updatedTarget });
    }
    catch (error) {
        console.error('Learning Target PUT Error:', error);
        res.status(500).json({ error: 'Failed to update learning target.' });
    }
});
exports.default = router;
