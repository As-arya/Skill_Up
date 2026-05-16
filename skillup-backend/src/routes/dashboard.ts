import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { requireAuth, AuthRequest } from '../middlewares/auth';

const router = Router();

// ─── GET /api/dashboard ──────────────────────────────────────────
router.get('/', requireAuth, async (req: AuthRequest, res: Response): Promise<void> => {
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
      prisma.user.findUnique({ where: { id: userId }, select: { name: true } }),
      prisma.skill.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } }),
      prisma.project.count({ where: { userId } }),
      prisma.learningTarget.findFirst({ 
        where: { userId, isCompleted: false }, 
        orderBy: { createdAt: 'desc' } 
      }),
    ]);

    const targetRoleName = target ? target.skillName : null;

    const totalSkills = allSkills.length;
    const masteredSkills = allSkills.filter(s => s.isChecked);
    const acquiredCount = masteredSkills.length;

    let jobReadiness = 0;
    let skillGap = 0;
    let skillsToMaster = 0;

    if (totalSkills > 0) {
      jobReadiness = Math.round((acquiredCount / totalSkills) * 100);
      skillGap = 100 - jobReadiness;
      skillsToMaster = totalSkills - acquiredCount;
    } else if (targetRoleName) {
      jobReadiness = 0;
      skillGap = 100;
      skillsToMaster = 0;
    }

    // Build grouped skills summary for homepage
    const groupMap = new Map<string, { total: number; mastered: number }>();
    for (const skill of allSkills) {
      const group = skill.category || 'General';
      if (!groupMap.has(group)) groupMap.set(group, { total: 0, mastered: 0 });
      const entry = groupMap.get(group)!;
      entry.total++;
      if (skill.isChecked) entry.mastered++;
    }

    const groupedSkills = Array.from(groupMap.entries()).map(([name, data]) => ({
      name,
      total: data.total,
      mastered: data.mastered,
      percentage: data.total > 0 ? Math.round((data.mastered / data.total) * 100) : 0,
    }));

    const topSkills = masteredSkills.slice(0, 5).map(s => ({ name: s.name, mastered: true }));

    // ─── Daily Goal: sub-skill based ────────────────────────────
    // Find skills in the category matching the learning target's skillName.
    // If no skills exist in that category, return null (card is hidden).
    let dailyGoalObj: object | null = null;
    if (target) {
      const categorySkills = allSkills.filter(
        s => (s.category || 'General').toLowerCase() === target.skillName.toLowerCase()
      );

      if (categorySkills.length > 0) {
        const masteredInCategory = categorySkills.filter(s => s.isChecked).length;
        const progressPercent = categorySkills.length > 0
          ? masteredInCategory / categorySkills.length
          : 0;

        // Pick up to 3 sub-skills to highlight: prioritise unchecked first, then checked
        const unchecked = categorySkills.filter(s => !s.isChecked);
        const checked   = categorySkills.filter(s => s.isChecked);
        const featured  = [...unchecked, ...checked].slice(0, 3);

        dailyGoalObj = {
          targetId:       target.id,
          categoryName:   target.skillName,
          totalSubSkills: categorySkills.length,
          mastered:       masteredInCategory,
          progressPercent,
          subSkills: featured.map(s => ({
            id:        s.id,
            name:      s.name,
            isChecked: s.isChecked,
          })),
        };
      }
      // else: dailyGoalObj stays null → card hidden on frontend
    }

    res.status(200).json({
      userName: user?.name || 'User',
      targetRole: targetRoleName || null,
      jobReadiness,
      skillGap,
      skillsToMaster,
      projectCount: projects,
      topSkills,
      groupedSkills,
      dailyGoal: dailyGoalObj,
    });
  } catch (error) {
    console.error('Dashboard Error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard data.' });
  }
});

// ─── GET /api/dashboard/categories ──────────────────────────────
// Returns all skill categories the user has, with completion stats.
// Used by the "Set Goal" picker on the home page.
router.get('/categories', requireAuth, async (req: AuthRequest, res: Response): Promise<void> => {
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

    const skills = await prisma.skill.findMany({ where: { userId } });

    const catMap = new Map<string, { total: number; mastered: number }>();
    for (const s of skills) {
      const cat = s.category || 'General';
      if (!catMap.has(cat)) catMap.set(cat, { total: 0, mastered: 0 });
      const e = catMap.get(cat)!;
      e.total++;
      if (s.isChecked) e.mastered++;
    }

    const categories = Array.from(catMap.entries()).map(([name, d]) => ({
      name,
      total: d.total,
      mastered: d.mastered,
      percentage: d.total > 0 ? Math.round((d.mastered / d.total) * 100) : 0,
    }));

    res.status(200).json({ categories });
  } catch (error) {
    console.error('Dashboard Categories Error:', error);
    res.status(500).json({ error: 'Failed to fetch categories.' });
  }
});

export default router;
