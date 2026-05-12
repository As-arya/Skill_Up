import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
dotenv.config();
import authRoutes from './routes/auth';
import dashboardRoutes from './routes/dashboard';
import skillsRoutes from './routes/skills';
import projectsRoutes from './routes/projects';
import learningTargetsRoutes from './routes/learning-targets';
import profileRoutes from './routes/profile';
import aiRoutes from './routes/ai';

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/api', authRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/skills', skillsRoutes);
app.use('/api/projects', projectsRoutes);
app.use('/api/learning-targets', learningTargetsRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api', aiRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});
