"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../lib/prisma");
const auth_1 = require("../lib/auth");
const router = (0, express_1.Router)();
router.post('/login', async (req, res) => {
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
        const user = await prisma_1.prisma.user.findUnique({ where: { email } });
        if (!user) {
            res.status(401).json({ error: 'Invalid email or password' });
            return;
        }
        const isValid = await (0, auth_1.verifyPassword)(password, user.password);
        if (!isValid) {
            res.status(401).json({ error: 'Invalid email or password' });
            return;
        }
        const token = (0, auth_1.signToken)({ userId: user.id, email: user.email });
        res.status(200).json({
            message: 'Login successful',
            token,
            user: { id: user.id, name: user.name, email: user.email }
        });
    }
    catch (error) {
        console.error('Login Error:', error);
        res.status(500).json({ error: 'Failed to process login.' });
    }
});
router.post('/register', async (req, res) => {
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
        const existingUser = await prisma_1.prisma.user.findUnique({ where: { email } });
        if (existingUser) {
            res.status(409).json({ error: 'Email already registered' });
            return;
        }
        const hashedPassword = await (0, auth_1.hashPassword)(password);
        const newUser = await prisma_1.prisma.user.create({
            data: {
                name,
                email,
                university: university || null,
                password: hashedPassword,
            },
        });
        const token = (0, auth_1.signToken)({ userId: newUser.id, email: newUser.email });
        res.status(201).json({
            message: 'Registration successful',
            token,
            user: { id: newUser.id, name: newUser.name, email: newUser.email }
        });
    }
    catch (error) {
        console.error('Register Error:', error);
        res.status(500).json({ error: 'Failed to process registration.' });
    }
});
exports.default = router;
