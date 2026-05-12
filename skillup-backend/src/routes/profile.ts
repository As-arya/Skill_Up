import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { requireAuth, AuthRequest } from '../middlewares/auth';

const router = Router();

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

    const user = await prisma.user.findUnique({
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
  } catch (error) {
    console.error('Profile GET Error:', error);
    res.status(500).json({ error: 'Failed to fetch profile.' });
  }
});

export default router;
