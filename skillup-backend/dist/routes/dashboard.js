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
        const [user, totalSkills, acquiredSkills, projects, target, skillsList] = await Promise.all([
            prisma_1.prisma.user.findUnique({ where: { id: userId }, select: { name: true } }),
            prisma_1.prisma.skill.count({ where: { userId } }),
            prisma_1.prisma.skill.count({ where: { userId, isChecked: true } }),
            prisma_1.prisma.project.count({ where: { userId } }),
            prisma_1.prisma.learningTarget.findFirst({ where: { userId }, orderBy: { createdAt: 'desc' } }),
            prisma_1.prisma.skill.findMany({ where: { userId, isChecked: true }, take: 5, orderBy: { createdAt: 'desc' } })
        ]);
        const targetRoleName = target ? target.skillName : null;
        // Simulate Job Readiness based on acquired skills (max 10 for 100%)
        let jobReadiness = 0;
        let skillGap = 0;
        let skillsToMaster = 0;
        if (targetRoleName) {
            jobReadiness = Math.min(100, Math.round((acquiredSkills / 10) * 100));
            if (jobReadiness === 0)
                jobReadiness = 15; // Give baseline progress
            skillGap = 100 - jobReadiness;
            skillsToMaster = Math.max(0, 10 - acquiredSkills);
        }
        const topSkills = skillsList.map(s => ({ name: s.name, mastered: true }));
        res.status(200).json({
            userName: user?.name || 'User',
            targetRole: targetRoleName || null,
            jobReadiness,
            skillGap,
            skillsToMaster,
            projectCount: projects,
            topSkills: topSkills || [],
        });
    }
    catch (error) {
        console.error('Dashboard Error:', error);
        res.status(500).json({ error: 'Failed to fetch dashboard data.' });
    }
});
exports.default = router;
