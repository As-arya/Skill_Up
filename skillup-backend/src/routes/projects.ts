import { Router, Response } from 'express';
import { prisma } from '../lib/prisma';
import { requireAuth, AuthRequest } from '../middlewares/auth';
import { callHybridAI, extractJSON } from './ai';

const router = Router();

function parseTagsRobustly(tagsData: any): string[] {
  let parsed = tagsData;
  try {
    // If it was double-stringified in SQLite, parse until it's an object/array
    while (typeof parsed === 'string') {
      const prev = parsed;
      parsed = JSON.parse(parsed);
      if (parsed === prev) break;
    }
  } catch (e) {
    // ignore
  }
  return Array.isArray(parsed) ? parsed : [];
}

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

    const projects = await prisma.project.findMany({
      where: { userId },
      include: { links: true },
      orderBy: { createdAt: 'desc' },
    });

    const formattedProjects = projects.map(p => ({
      ...p,
      tags: parseTagsRobustly(p.tags),
    }));

    res.status(200).json({ projects: formattedProjects });
  } catch (error) {
    console.error('Projects GET Error:', error);
    res.status(500).json({ error: 'Failed to fetch projects.' });
  }
});

router.post('/', requireAuth, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId, title, description, tags, links } = req.body;

    if (!userId || !title || !description || !tags || !Array.isArray(tags)) {
      res.status(400).json({ error: 'Missing required fields or invalid tags format' });
      return;
    }

    if (req.user?.userId !== userId) {
      res.status(403).json({ error: 'Forbidden: Access denied' });
      return;
    }

    const project = await prisma.project.create({
      data: {
        userId,
        title,
        description,
        tags: JSON.stringify(tags),
        links: {
          create: Array.isArray(links) ? links.map((link: any) => ({
            type: link.type || 'Link',
            url: link.url || ''
          })) : []
        }
      },
      include: { links: true },
    });

    const formattedProject = {
      ...project,
      tags: parseTagsRobustly(project.tags),
    };

    res.status(201).json({ project: formattedProject });
  } catch (error) {
    console.error('Project POST Error:', error);
    res.status(500).json({ error: 'Failed to create project.' });
  }
});

router.get('/fetch-readme', requireAuth, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { repoUrl } = req.query;
    if (!repoUrl || typeof repoUrl !== 'string') {
      res.status(400).json({ error: 'Valid repoUrl query parameter is required' });
      return;
    }

    // Extract owner and repo from https://github.com/owner/repo
    const match = repoUrl.match(/github\.com\/([^\/]+)\/([^\/]+)/);
    if (!match) {
      res.status(400).json({ error: 'Invalid GitHub URL format' });
      return;
    }

    const owner = match[1];
    let repo = match[2];
    if (repo.endsWith('.git')) repo = repo.slice(0, -4);

    const apiUrl = `https://api.github.com/repos/${owner}/${repo}/readme`;
    const response = await fetch(apiUrl, {
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'SkillUp-App'
      }
    });

    if (!response.ok) {
      res.status(response.status).json({ error: 'Failed to fetch README from GitHub' });
      return;
    }

    const data = await response.json();
    if (!data.content || data.encoding !== 'base64') {
      res.status(500).json({ error: 'Unexpected response format from GitHub' });
      return;
    }

    const markdown = Buffer.from(data.content, 'base64').toString('utf-8');
    
    const cacheKey = `readme-tags-${owner}-${repo}`;
    const aiText = await callHybridAI({
      prompt: `Extract up to 5 main technical tags or frameworks (e.g., "Flutter", "Node.js", "Firebase", "React") from the following project README. Respond ONLY with a JSON array of strings: ["tag1", "tag2"]. README: ${markdown.substring(0, 5000)}`,
      cacheKey
    });
    
    const tags = extractJSON(aiText) || [];
    res.status(200).json({ tags });
  } catch (error) {
    console.error('Fetch README Error:', error);
    res.status(500).json({ error: 'Failed to fetch README.' });
  }
});

export default router;
