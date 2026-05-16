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
        const [user, allSkills, projects, target] = await Promise.all([
            prisma_1.prisma.user.findUnique({ where: { id: userId }, select: { name: true } }),
            prisma_1.prisma.skill.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } }),
            prisma_1.prisma.project.count({ where: { userId } }),
            prisma_1.prisma.learningTarget.findFirst({ where: { userId }, orderBy: { createdAt: 'desc' } }),
        ]);
        const targetRoleName = target ? target.skillName : null;
        const totalSkills = allSkills.length;
        const masteredSkills = allSkills.filter(s => s.isChecked);
        const acquiredCount = masteredSkills.length;
        // Real percentage: (mastered / total) * 100
        let jobReadiness = 0;
        let skillGap = 0;
        let skillsToMaster = 0;
        if (totalSkills > 0) {
            jobReadiness = Math.round((acquiredCount / totalSkills) * 100);
            skillGap = 100 - jobReadiness;
            skillsToMaster = totalSkills - acquiredCount;
        }
        else if (targetRoleName) {
            // User has a target but no skills tracked yet
            jobReadiness = 0;
            skillGap = 100;
            skillsToMaster = 0;
        }
        // Build grouped skills summary for homepage
        const groupMap = new Map();
        for (const skill of allSkills) {
            const group = skill.category || 'General';
            if (!groupMap.has(group))
                groupMap.set(group, { total: 0, mastered: 0 });
            const entry = groupMap.get(group);
            entry.total++;
            if (skill.isChecked)
                entry.mastered++;
        }
        const groupedSkills = Array.from(groupMap.entries()).map(([name, data]) => ({
            name,
            total: data.total,
            mastered: data.mastered,
            percentage: data.total > 0 ? Math.round((data.mastered / data.total) * 100) : 0,
        }));
        // Top 5 mastered skills for display
        const topSkills = masteredSkills.slice(0, 5).map(s => ({ name: s.name, mastered: true }));
        res.status(200).json({
            userName: user?.name || 'User',
            targetRole: targetRoleName || null,
            jobReadiness,
            skillGap,
            skillsToMaster,
            projectCount: projects,
            topSkills,
            groupedSkills,
        });
    }
    catch (error) {
        console.error('Dashboard Error:', error);
        res.status(500).json({ error: 'Failed to fetch dashboard data.' });
    }
});
exports.default = router;
