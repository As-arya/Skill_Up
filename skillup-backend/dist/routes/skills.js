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
        // Build grouped structure
        const groupMap = new Map();
        for (const skill of skills) {
            const group = skill.category || 'General';
            if (!groupMap.has(group))
                groupMap.set(group, { skills: [], mastered: 0 });
            const entry = groupMap.get(group);
            entry.skills.push(skill);
            if (skill.isChecked)
                entry.mastered++;
        }
        const grouped = Array.from(groupMap.entries()).map(([name, data]) => ({
            group: name,
            percentage: data.skills.length > 0 ? Math.round((data.mastered / data.skills.length) * 100) : 0,
            skills: data.skills,
        }));
        // Separate mastered (100%) groups from active gaps
        const masteredGroups = grouped.filter(g => g.percentage === 100);
        const activeGroups = grouped.filter(g => g.percentage < 100);
        const totalSkills = skills.length;
        const totalMastered = skills.filter(s => s.isChecked).length;
        const overallPercentage = totalSkills > 0 ? Math.round((totalMastered / totalSkills) * 100) : 0;
        res.status(200).json({
            skills,
            grouped: activeGroups,
            masteredGroups,
            overallPercentage,
            totalSkills,
            totalMastered,
        });
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
            // Skill already exists — do NOT overwrite isChecked or other fields.
            // Only update the category if a new one is provided and current is 'General'.
            if (category && existing.category === 'General' && category !== 'General') {
                const updated = await prisma_1.prisma.skill.update({
                    where: { id: existing.id },
                    data: { category }
                });
                res.status(200).json({ skill: updated, alreadyExisted: true });
            }
            else {
                res.status(200).json({ skill: existing, alreadyExisted: true });
            }
            return;
        }
        const skill = await prisma_1.prisma.skill.create({
            data: {
                userId,
                name,
                category: category || 'General',
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
// POST /api/skills/confirm-mastery — bulk-mark skills as mastered (from portfolio confirmation popup)
router.post('/confirm-mastery', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, skillNames } = req.body;
        if (!userId || !Array.isArray(skillNames) || skillNames.length === 0) {
            res.status(400).json({ error: 'userId and skillNames[] are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        let updated = 0;
        for (const name of skillNames) {
            const skill = await prisma_1.prisma.skill.findFirst({ where: { userId, name } });
            if (skill && !skill.isChecked) {
                await prisma_1.prisma.skill.update({ where: { id: skill.id }, data: { isChecked: true } });
                updated++;
            }
        }
        res.status(200).json({ message: `${updated} skill(s) marked as mastered.`, updated });
    }
    catch (error) {
        console.error('Confirm Mastery Error:', error);
        res.status(500).json({ error: 'Failed to confirm mastery.' });
    }
});
// POST /api/skills/cleanup — remove corrupted skills with raw map toString names
router.post('/cleanup', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId } = req.body;
        if (!userId) {
            res.status(400).json({ error: 'userId is required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden: Access denied' });
            return;
        }
        // Find skills whose names look like raw Map.toString() output
        const allSkills = await prisma_1.prisma.skill.findMany({ where: { userId } });
        const corruptedIds = allSkills
            .filter(s => s.name.startsWith('{') && s.name.includes('group:'))
            .map(s => s.id);
        if (corruptedIds.length > 0) {
            await prisma_1.prisma.skill.deleteMany({ where: { id: { in: corruptedIds } } });
        }
        // Also rename legacy 'HARD' category to 'General'
        await prisma_1.prisma.skill.updateMany({
            where: { userId, category: 'HARD' },
            data: { category: 'General' },
        });
        res.status(200).json({ message: `Cleaned up ${corruptedIds.length} corrupted skill(s).`, deleted: corruptedIds.length });
    }
    catch (error) {
        console.error('Skills Cleanup Error:', error);
        res.status(500).json({ error: 'Failed to cleanup skills.' });
    }
});
exports.default = router;
