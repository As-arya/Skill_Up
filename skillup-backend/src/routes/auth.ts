import { Router, Request, Response } from 'express';
import { prisma } from '../lib/prisma';
import { hashPassword, verifyPassword, signToken } from '../lib/auth';

const router = Router();

router.post('/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required' });
      return;
    }

    if (email.includes(' ') || !email.includes('@')) {
      res.status(400).json({ error: 'Invalid email format' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, name: true, email: true, password: true },
    });
    if (!user) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const isValid = await verifyPassword(password, user.password);
    if (!isValid) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const token = signToken({ userId: user.id, email: user.email });

    res.status(200).json({
      message: 'Login successful',
      token,
      user: { id: user.id, name: user.name, email: user.email }
    });
  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Failed to process login.' });
  }
});

router.post('/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, email, password, university } = req.body;

    if (!name || !email || !password) {
      res.status(400).json({ error: 'Name, email, and password are required' });
      return;
    }

    if (name.trim().length <= 3) {
      res.status(400).json({ error: 'Name must be more than 3 characters' });
      return;
    }

    if (email.includes(' ') || !email.includes('@')) {
      res.status(400).json({ error: 'Invalid email format (no spaces, must contain @)' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    const existingUser = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (existingUser) {
      res.status(409).json({ error: 'Email already registered' });
      return;
    }

    const hashedPassword = await hashPassword(password);

    const newUser = await prisma.user.create({
      data: {
        name,
        email,
        university: university || null,
        password: hashedPassword,
      },
      select: { id: true, name: true, email: true },
    });

    const token = signToken({ userId: newUser.id, email: newUser.email });

    res.status(201).json({
      message: 'Registration successful',
      token,
      user: { id: newUser.id, name: newUser.name, email: newUser.email }
    });
  } catch (error) {
    console.error('Register Error:', error);
    res.status(500).json({ error: 'Failed to process registration.' });
  }
});

export default router;
