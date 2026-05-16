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
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

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

// Export for Vercel serverless — also start normally for local dev / Railway
if (process.env.VERCEL !== '1') {
  app.listen(Number(port), '0.0.0.0', () => {
    console.log(`[server]: Server is running at http://0.0.0.0:${port}`);
    console.log(`[server]: Accessible from Android emulator at http://10.0.2.2:${port}`);
  });
}

export default app;
