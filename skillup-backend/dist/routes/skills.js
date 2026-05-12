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
        const skills = await prisma_1.prisma.skill.findMany({
            where: { userId },
            orderBy: { createdAt: 'asc' },
        });
        res.status(200).json({ skills });
    }
    catch (error) {
        console.error('Skills GET Error:', error);
        res.status(500).json({ error: 'Failed to fetch skills.' });
    }
});
router.post('/', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, name, isChecked, category } = req.body;
        if (!userId || !name) {
            res.status(400).json({ error: 'userId and name are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        // Check if skill already exists
        const existing = await prisma_1.prisma.skill.findFirst({
            where: { userId, name }
        });
        if (existing) {
            const updated = await prisma_1.prisma.skill.update({
                where: { id: existing.id },
                data: { isChecked: isChecked !== undefined ? isChecked : true }
            });
            res.status(200).json({ skill: updated });
            return;
        }
        const skill = await prisma_1.prisma.skill.create({
            data: {
                userId,
                name,
                category: category || 'HARD',
                isChecked: isChecked !== undefined ? isChecked : true
            }
        });
        res.status(201).json({ skill });
    }
    catch (error) {
        console.error('Skills POST Error:', error);
        res.status(500).json({ error: 'Failed to create skill.' });
    }
});
router.put('/:id', auth_1.requireAuth, async (req, res) => {
    try {
        const id = Number(req.params.id);
        const { isChecked, name } = req.body;
        if (isNaN(id)) {
            res.status(400).json({ error: 'Invalid skill ID' });
            return;
        }
        // At least one field must be provided
        if (typeof isChecked !== 'boolean' && !name) {
            res.status(400).json({ error: 'Provide isChecked (boolean) or name (string)' });
            return;
        }
        const skill = await prisma_1.prisma.skill.findUnique({ where: { id } });
        if (!skill) {
            res.status(404).json({ error: 'Skill not found' });
            return;
        }
        if (skill.userId !== req.user?.userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        const updateData = {};
        if (typeof isChecked === 'boolean')
            updateData.isChecked = isChecked;
        if (name && typeof name === 'string')
            updateData.name = name.trim();
        const updatedSkill = await prisma_1.prisma.skill.update({
            where: { id },
            data: updateData,
        });
        res.status(200).json({ skill: updatedSkill });
    }
    catch (error) {
        console.error('Skill PUT Error:', error);
        res.status(500).json({ error: 'Failed to update skill.' });
    }
});
router.delete('/:id', auth_1.requireAuth, async (req, res) => {
    try {
        const id = Number(req.params.id);
        if (isNaN(id)) {
            res.status(400).json({ error: 'Invalid skill ID' });
            return;
        }
        const skill = await prisma_1.prisma.skill.findUnique({ where: { id } });
        if (!skill) {
            res.status(404).json({ error: 'Skill not found' });
            return;
        }
        if (skill.userId !== req.user?.userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        await prisma_1.prisma.skill.delete({ where: { id } });
        res.status(200).json({ message: 'Skill deleted successfully' });
    }
    catch (error) {
        console.error('Skill DELETE Error:', error);
        res.status(500).json({ error: 'Failed to delete skill.' });
    }
});
exports.default = router;
