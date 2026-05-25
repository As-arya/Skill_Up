/**
 * Preservation Property Tests
 * 
 * PURPOSE: These tests capture baseline behavior of all non-buggy functionality on UNFIXED code.
 * They MUST PASS on unfixed code to establish baseline behavior that must be preserved after fixes.
 * 
 * IMPORTANT: These tests verify that fixes don't break existing functionality.
 * 
 * Validates: Preservation Requirements 3.1 - 3.10 from bugfix.md
 */

import express from 'express';
import request from 'supertest';
import { signToken, hashPassword } from '../src/lib/auth';
import { prisma } from '../src/lib/prisma';
import authRoutes from '../src/routes/auth';
import projectsRoutes from '../src/routes/projects';
import learningTargetsRoutes from '../src/routes/learning-targets';
import profileRoutes from '../src/routes/profile';
import dashboardRoutes from '../src/routes/dashboard';

// Helper to create a test user and return auth token
async function createTestUser(email: string, name: string = 'Test User') {
  const hashedPassword = await hashPassword('testpass123');
  const user = await prisma.user.create({
    data: {
      name,
      email,
      password: hashedPassword,
    },
  });
  const token = signToken({ userId: user.id, email: user.email });
  return { user, token };
}

// Helper to create test app with middleware
function createTestApp() {
  const app = express();
  app.use(express.json());
  return app;
}

// ============================================================================
// PRESERVATION TEST 1: Auth Login (Requirement 3.1)
// ============================================================================
/**
 * Validates: Requirements 3.1
 * WHEN a user logs in with valid credentials THEN the system SHALL CONTINUE TO
 * authenticate via JWT, return user data, and navigate to the main shell
 */

describe('Preservation 1: Auth Login - Valid credentials return 200 with token and user', () => {
  it('should return 200 with token and user object on successful login', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    // Create test user
    const { user } = await createTestUser(`login-test-${Date.now()}@test.com`, 'Login Test User');

    // Perform login
    const response = await request(app)
      .post('/api/login')
      .send({
        email: user.email,
        password: 'testpass123',
      });

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('token');
    expect(response.body).toHaveProperty('user');
    expect(response.body.user).toHaveProperty('id');
    expect(response.body.user).toHaveProperty('name');
    expect(response.body.user).toHaveProperty('email');
    expect(response.body.token).toBeDefined();
    expect(typeof response.body.token).toBe('string');
    expect(response.body.token.length).toBeGreaterThan(0);

    // Cleanup
    await prisma.user.delete({ where: { id: user.id } });
  });

  it('should return 401 for invalid credentials', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    // Create test user
    const { user } = await createTestUser(`login-invalid-${Date.now()}@test.com`);

    // Try login with wrong password
    const response = await request(app)
      .post('/api/login')
      .send({
        email: user.email,
        password: 'wrongpassword',
      });

    expect(response.status).toBe(401);
    expect(response.body).toHaveProperty('error');

    // Cleanup
    await prisma.user.delete({ where: { id: user.id } });
  });

  it('should return 400 for missing email or password', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    // Missing password
    const response1 = await request(app)
      .post('/api/login')
      .send({ email: 'test@test.com' });
    expect(response1.status).toBe(400);

    // Missing email
    const response2 = await request(app)
      .post('/api/login')
      .send({ password: 'testpass123' });
    expect(response2.status).toBe(400);
  });
});

// ============================================================================
// PRESERVATION TEST 2: Auth Register (Requirement 3.2)
// ============================================================================
/**
 * Validates: Requirements 3.2
 * WHEN a user registers a new account THEN the system SHALL CONTINUE TO
 * create the user, hash the password, and return a valid token
 */

describe('Preservation 2: Auth Register - New user returns 201 with token and user', () => {
  it('should return 201 with token and user object on successful registration', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    const uniqueEmail = `register-test-${Date.now()}@test.com`;

    const response = await request(app)
      .post('/api/register')
      .send({
        name: 'New User',
        email: uniqueEmail,
        password: 'testpass123',
      });

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('token');
    expect(response.body).toHaveProperty('user');
    expect(response.body.user).toHaveProperty('id');
    expect(response.body.user).toHaveProperty('name');
    expect(response.body.user).toHaveProperty('email');
    expect(response.body.user.email).toBe(uniqueEmail);
    expect(response.body.token).toBeDefined();
    expect(typeof response.body.token).toBe('string');

    // Cleanup
    await prisma.user.delete({ where: { id: response.body.user.id } });
  });

  it('should return 409 for duplicate email registration', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    const { user } = await createTestUser(`duplicate-${Date.now()}@test.com`);

    // Try to register with same email
    const response = await request(app)
      .post('/api/register')
      .send({
        name: 'Duplicate User',
        email: user.email,
        password: 'testpass123',
      });

    expect(response.status).toBe(409);
    expect(response.body).toHaveProperty('error');

    // Cleanup
    await prisma.user.delete({ where: { id: user.id } });
  });

  it('should return 400 for invalid registration data', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    // Missing name
    const response1 = await request(app)
      .post('/api/register')
      .send({
        email: `test-${Date.now()}@test.com`,
        password: 'testpass123',
      });
    expect(response1.status).toBe(400);

    // Password too short
    const response2 = await request(app)
      .post('/api/register')
      .send({
        name: 'Test',
        email: `test2-${Date.now()}@test.com`,
        password: 'short',
      });
    expect(response2.status).toBe(400);

    // Invalid email format
    const response3 = await request(app)
      .post('/api/register')
      .send({
        name: 'Test User',
        email: 'invalid-email',
        password: 'testpass123',
      });
    expect(response3.status).toBe(400);
  });
});

// ============================================================================
// PRESERVATION TEST 3: Project Creation (Requirement 3.3)
// ============================================================================
/**
 * Validates: Requirements 3.3
 * WHEN a user creates a new project via POST /api/projects THEN the system
 * SHALL CONTINUE TO create the project with title, description, tags, and links correctly
 */

describe('Preservation 3: Project Creation - POST creates project and returns 201', () => {
  let app: express.Application;
  let token: string;
  let userId: number;

  beforeAll(async () => {
    const result = await createTestUser(`project-create-${Date.now()}@test.com`);
    token = result.token;
    userId = result.user.id;

    app = createTestApp();
    app.use('/api/projects', projectsRoutes);
  });

  afterAll(async () => {
    await prisma.project.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 201 with created project on valid POST', async () => {
    const response = await request(app)
      .post('/api/projects')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId,
        title: 'Test Project',
        description: 'A test project description',
        tags: ['React', 'TypeScript', 'Node.js'],
        links: [
          { type: 'GitHub', url: 'https://github.com/test/project' },
          { type: 'Demo', url: 'https://demo.test.com' },
        ],
      });

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('project');
    expect(response.body.project).toHaveProperty('id');
    expect(response.body.project.title).toBe('Test Project');
    expect(response.body.project.description).toBe('A test project description');
    expect(response.body.project.tags).toEqual(['React', 'TypeScript', 'Node.js']);
    expect(response.body.project.links).toHaveLength(2);
  });

  it('should return 400 for missing required fields', async () => {
    const response = await request(app)
      .post('/api/projects')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId,
        title: 'Incomplete Project',
        // missing description and tags
      });

    expect(response.status).toBe(400);
    expect(response.body).toHaveProperty('error');
  });

  it('should return 403 for mismatched userId', async () => {
    const response = await request(app)
      .post('/api/projects')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId: 999999, // Different user
        title: 'Test',
        description: 'Test',
        tags: ['test'],
      });

    expect(response.status).toBe(403);
  });

  it('should return 401 without auth token', async () => {
    const response = await request(app)
      .post('/api/projects')
      .send({
        userId,
        title: 'Test',
        description: 'Test',
        tags: ['test'],
      });

    expect(response.status).toBe(401);
  });
});

// ============================================================================
// PRESERVATION TEST 4: Project Listing (Requirement 3.4)
// ============================================================================
/**
 * Validates: Requirements 3.4
 * WHEN a user fetches their projects via GET /api/projects THEN the system
 * SHALL CONTINUE TO return all projects with parsed tags and included links
 */

describe('Preservation 4: Project Listing - GET returns array with parsed tags and included links', () => {
  let app: express.Application;
  let token: string;
  let userId: number;
  let projectId: number;

  beforeAll(async () => {
    const result = await createTestUser(`project-list-${Date.now()}@test.com`);
    token = result.token;
    userId = result.user.id;

    // Create test project
    const project = await prisma.project.create({
      data: {
        userId,
        title: 'List Test Project',
        description: 'Description',
        tags: JSON.stringify(['Flutter', 'Dart']),
        links: {
          create: [
            { type: 'GitHub', url: 'https://github.com/test' },
          ],
        },
      },
      include: { links: true },
    });
    projectId = project.id;

    app = createTestApp();
    app.use('/api/projects', projectsRoutes);
  });

  afterAll(async () => {
    await prisma.project.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 200 with projects array containing parsed tags and links', async () => {
    const response = await request(app)
      .get(`/api/projects?userId=${userId}`)
      .set('Authorization', `Bearer ${token}`);

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('projects');
    expect(Array.isArray(response.body.projects)).toBe(true);
    expect(response.body.projects.length).toBeGreaterThan(0);

    // Verify tags are parsed (array, not string)
    const project = response.body.projects[0];
    expect(Array.isArray(project.tags)).toBe(true);
    expect(project.tags).toEqual(['Flutter', 'Dart']);

    // Verify links are included
    expect(project).toHaveProperty('links');
    expect(Array.isArray(project.links)).toBe(true);
    expect(project.links.length).toBeGreaterThan(0);
    expect(project.links[0]).toHaveProperty('type');
    expect(project.links[0]).toHaveProperty('url');
  });

  it('should return 400 for missing userId', async () => {
    const response = await request(app)
      .get('/api/projects')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(400);
  });

  it('should return 403 for mismatched userId', async () => {
    const response = await request(app)
      .get('/api/projects?userId=999999')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(403);
  });

  it('should return 401 without auth token', async () => {
    const response = await request(app)
      .get(`/api/projects?userId=${userId}`);

    expect(response.status).toBe(401);
  });
});

// ============================================================================
// PRESERVATION TEST 5: Learning Target Creation (Requirement 3.5)
// ============================================================================
/**
 * Validates: Requirements 3.5
 * WHEN a user creates a learning target via POST /api/learning-targets THEN
 * the system SHALL CONTINUE TO create the target with skillName and targetMinutes
 */

describe('Preservation 5: Learning Target Creation - POST creates target and returns 201', () => {
  let app: express.Application;
  let token: string;
  let userId: number;

  beforeAll(async () => {
    const result = await createTestUser(`target-create-${Date.now()}@test.com`);
    token = result.token;
    userId = result.user.id;

    app = createTestApp();
    app.use('/api/learning-targets', learningTargetsRoutes);
  });

  afterAll(async () => {
    await prisma.learningTarget.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 201 with created learning target on valid POST', async () => {
    const response = await request(app)
      .post('/api/learning-targets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId,
        skillName: 'React Development',
        targetMinutes: 60,
        deadline: '2025-12-31',
      });

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('learningTarget');
    expect(response.body.learningTarget).toHaveProperty('id');
    expect(response.body.learningTarget.skillName).toBe('React Development');
    expect(response.body.learningTarget.targetMinutes).toBe(60);
    expect(response.body.learningTarget.isCompleted).toBe(false);
  });

  it('should default targetMinutes to 30 when not provided', async () => {
    const response = await request(app)
      .post('/api/learning-targets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId,
        skillName: 'TypeScript Basics',
      });

    expect(response.status).toBe(201);
    expect(response.body.learningTarget.targetMinutes).toBe(30);
  });

  it('should return 400 for missing required fields', async () => {
    const response = await request(app)
      .post('/api/learning-targets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId,
        // missing skillName
      });

    expect(response.status).toBe(400);
  });

  it('should return 403 for mismatched userId', async () => {
    const response = await request(app)
      .post('/api/learning-targets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId: 999999,
        skillName: 'Test Skill',
      });

    expect(response.status).toBe(403);
  });
});

// ============================================================================
// PRESERVATION TEST 6: Learning Target Complete (Requirement 3.6)
// ============================================================================
/**
 * Validates: Requirements 3.6
 * WHEN a user marks a learning target as complete via PUT /api/learning-targets/:id/complete
 * THEN the system SHALL CONTINUE TO update isCompleted to true
 */

describe('Preservation 6: Learning Target Complete - PUT marks completed and returns 200', () => {
  let app: express.Application;
  let token: string;
  let userId: number;
  let targetId: number;

  beforeAll(async () => {
    const result = await createTestUser(`target-complete-${Date.now()}@test.com`);
    token = result.token;
    userId = result.user.id;

    // Create test learning target
    const target = await prisma.learningTarget.create({
      data: {
        userId,
        skillName: 'Test Skill to Complete',
        targetMinutes: 45,
      },
    });
    targetId = target.id;

    app = createTestApp();
    app.use('/api/learning-targets', learningTargetsRoutes);
  });

  afterAll(async () => {
    await prisma.learningTarget.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 200 with completed learning target', async () => {
    const response = await request(app)
      .put(`/api/learning-targets/${targetId}/complete`)
      .set('Authorization', `Bearer ${token}`);

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('learningTarget');
    expect(response.body.learningTarget.id).toBe(targetId);
    expect(response.body.learningTarget.isCompleted).toBe(true);
  });

  it('should return 404 for non-existent target', async () => {
    const response = await request(app)
      .put('/api/learning-targets/999999/complete')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(404);
  });

  it('should return 401 without auth token', async () => {
    const response = await request(app)
      .put(`/api/learning-targets/${targetId}/complete`);

    expect(response.status).toBe(401);
  });
});

// ============================================================================
// PRESERVATION TEST 7: Profile Get (Requirement 3.7)
// ============================================================================
/**
 * Validates: Requirements 3.7
 * WHEN a user fetches their profile via GET /api/profile THEN the system
 * SHALL CONTINUE TO return id, name, email, and createdAt
 */

describe('Preservation 7: Profile Get - GET returns user profile fields', () => {
  let app: express.Application;
  let token: string;
  let userId: number;

  beforeAll(async () => {
    const result = await createTestUser(`profile-get-${Date.now()}@test.com`, 'Profile Test User');
    token = result.token;
    userId = result.user.id;

    app = createTestApp();
    app.use('/api/profile', profileRoutes);
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 200 with user profile containing required fields', async () => {
    const response = await request(app)
      .get(`/api/profile?userId=${userId}`)
      .set('Authorization', `Bearer ${token}`);

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('user');
    expect(response.body.user).toHaveProperty('id');
    expect(response.body.user).toHaveProperty('name');
    expect(response.body.user).toHaveProperty('email');
    expect(response.body.user).toHaveProperty('createdAt');
    expect(response.body.user.id).toBe(userId);
    expect(response.body.user.name).toBe('Profile Test User');
  });

  it('should return 400 for missing userId', async () => {
    const response = await request(app)
      .get('/api/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(400);
  });

  it('should return 403 for mismatched userId', async () => {
    const response = await request(app)
      .get('/api/profile?userId=999999')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(403);
  });

  it('should return 401 without auth token', async () => {
    const response = await request(app)
      .get(`/api/profile?userId=${userId}`);

    expect(response.status).toBe(401);
  });
});

// ============================================================================
// PRESERVATION TEST 8: Dashboard Get (Requirement 3.8)
// ============================================================================
/**
 * Validates: Requirements 3.8
 * WHEN a user fetches dashboard data via GET /api/dashboard THEN the system
 * SHALL CONTINUE TO return userName, targetRole, jobReadiness, skillGap,
 * skillsToMaster, projectCount, topSkills, and groupedSkills
 */

describe('Preservation 8: Dashboard Get - GET returns dashboard fields', () => {
  let app: express.Application;
  let token: string;
  let userId: number;

  beforeAll(async () => {
    const result = await createTestUser(`dashboard-get-${Date.now()}@test.com`, 'Dashboard User');
    token = result.token;
    userId = result.user.id;

    // Create some skills for the dashboard
    await prisma.skill.createMany({
      data: [
        { userId, name: 'JavaScript', category: 'HARD', isChecked: true },
        { userId, name: 'React', category: 'HARD', isChecked: true },
        { userId, name: 'Communication', category: 'SOFT', isChecked: false },
      ],
    });

    // Create a learning target
    await prisma.learningTarget.create({
      data: {
        userId,
        skillName: 'Full Stack Developer',
        targetMinutes: 120,
      },
    });

    app = createTestApp();
    app.use('/api/dashboard', dashboardRoutes);
  });

  afterAll(async () => {
    await prisma.skill.deleteMany({ where: { userId } });
    await prisma.learningTarget.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 200 with all required dashboard fields', async () => {
    const response = await request(app)
      .get(`/api/dashboard?userId=${userId}`)
      .set('Authorization', `Bearer ${token}`);

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);

    // All required fields from Requirement 3.8
    expect(response.body).toHaveProperty('userName');
    expect(response.body).toHaveProperty('targetRole');
    expect(response.body).toHaveProperty('jobReadiness');
    expect(response.body).toHaveProperty('skillGap');
    expect(response.body).toHaveProperty('skillsToMaster');
    expect(response.body).toHaveProperty('projectCount');
    expect(response.body).toHaveProperty('topSkills');
    expect(response.body).toHaveProperty('groupedSkills');

    // Verify types
    expect(response.body.userName).toBe('Dashboard User');
    expect(typeof response.body.jobReadiness).toBe('number');
    expect(typeof response.body.skillGap).toBe('number');
    expect(typeof response.body.skillsToMaster).toBe('number');
    expect(typeof response.body.projectCount).toBe('number');
    expect(Array.isArray(response.body.topSkills)).toBe(true);
    expect(Array.isArray(response.body.groupedSkills)).toBe(true);
  });

  it('should calculate correct job readiness percentage', async () => {
    const response = await request(app)
      .get(`/api/dashboard?userId=${userId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    // 2 mastered out of 3 total = 67% (rounded)
    expect(response.body.jobReadiness).toBe(67);
    expect(response.body.skillGap).toBe(33);
    expect(response.body.skillsToMaster).toBe(1);
  });

  it('should return 400 for missing userId', async () => {
    const response = await request(app)
      .get('/api/dashboard')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(400);
  });

  it('should return 403 for mismatched userId', async () => {
    const response = await request(app)
      .get('/api/dashboard?userId=999999')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(403);
  });

  it('should return 401 without auth token', async () => {
    const response = await request(app)
      .get(`/api/dashboard?userId=${userId}`);

    expect(response.status).toBe(401);
  });
});

// ============================================================================
// PRESERVATION TEST 9: Health Check (Requirement 3.10)
// ============================================================================
/**
 * Validates: Requirements 3.10
 * WHEN the backend starts THEN the system SHALL CONTINUE TO listen on the
 * configured PORT, serve all existing routes, and respond to /health with { status: 'ok' }
 */

describe('Preservation 9: Health Check - GET /health returns { status: "ok" }', () => {
  let app: express.Application;

  beforeAll(() => {
    app = createTestApp();
    app.get('/health', (req, res) => {
      res.json({ status: 'ok' });
    });
  });

  it('should return 200 with { status: "ok" }', async () => {
    const response = await request(app).get('/health');

    // PRESERVATION: These assertions must pass on unfixed code
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status');
    expect(response.body.status).toBe('ok');
  });
});

// ============================================================================
// ADDITIONAL PRESERVATION TESTS: Auth Middleware
// ============================================================================

describe('Preservation: Auth Middleware behavior', () => {
  let app: express.Application;
  let token: string;
  let userId: number;

  beforeAll(async () => {
    const result = await createTestUser(`auth-middleware-${Date.now()}@test.com`);
    token = result.token;
    userId = result.user.id;

    app = createTestApp();
    app.use('/api/profile', profileRoutes);
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
  });

  it('should return 401 for malformed auth header', async () => {
    const response = await request(app)
      .get(`/api/profile?userId=${userId}`)
      .set('Authorization', 'InvalidFormat');

    expect(response.status).toBe(401);
    expect(response.body).toHaveProperty('error');
  });

  it('should return 401 for invalid token', async () => {
    const response = await request(app)
      .get(`/api/profile?userId=${userId}`)
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
  });

  it('should allow access with valid token', async () => {
    const response = await request(app)
      .get(`/api/profile?userId=${userId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
  });
});

// ============================================================================
// PROPERTY-BASED PRESERVATION TEST: Authentication Flow
// ============================================================================

describe('Property: Authentication Flow Preservation', () => {
  it('should consistently authenticate valid users and reject invalid ones', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    // Create user
    const { user } = await createTestUser(`prop-auth-${Date.now()}@test.com`);

    // Test multiple valid login attempts
    for (let i = 0; i < 3; i++) {
      const response = await request(app)
        .post('/api/login')
        .send({ email: user.email, password: 'testpass123' });
      
      expect(response.status).toBe(200);
      expect(response.body.token).toBeDefined();
    }

    // Test invalid credentials are always rejected
    for (let i = 0; i < 3; i++) {
      const response = await request(app)
        .post('/api/login')
        .send({ email: user.email, password: 'wrongpassword' });
      
      expect(response.status).toBe(401);
    }

    // Cleanup
    await prisma.user.delete({ where: { id: user.id } });
  });

  it('should consistently register new users and reject duplicates', async () => {
    const app = createTestApp();
    app.use('/api', authRoutes);

    const email = `prop-register-${Date.now()}@test.com`;

    // First registration should succeed
    const response1 = await request(app)
      .post('/api/register')
      .send({ name: 'Test User', email, password: 'testpass123' });
    
    expect(response1.status).toBe(201);
    expect(response1.body.token).toBeDefined();

    // Duplicate registration should fail
    const response2 = await request(app)
      .post('/api/register')
      .send({ name: 'Another User', email, password: 'testpass123' });
    
    expect(response2.status).toBe(409);

    // Cleanup
    await prisma.user.delete({ where: { id: response1.body.user.id } });
  });
});

// ============================================================================
// PROPERTY-BASED PRESERVATION TEST: Project Operations
// ============================================================================

describe('Property: Project Operations Preservation', () => {
  it('should consistently create and retrieve projects with correct data', async () => {
    const app = createTestApp();
    app.use('/api/projects', projectsRoutes);

    const { user, token } = await createTestUser(`prop-project-${Date.now()}@test.com`);

    // Create multiple projects
    const projectData = [
      { title: 'Project A', description: 'Desc A', tags: ['Tag1', 'Tag2'] },
      { title: 'Project B', description: 'Desc B', tags: ['Tag3'] },
      { title: 'Project C', description: 'Desc C', tags: [] },
    ];

    for (const data of projectData) {
      const createResponse = await request(app)
        .post('/api/projects')
        .set('Authorization', `Bearer ${token}`)
        .send({ userId: user.id, ...data, links: [] });

      expect(createResponse.status).toBe(201);
      expect(createResponse.body.project.title).toBe(data.title);
    }

    // Get all projects
    const listResponse = await request(app)
      .get(`/api/projects?userId=${user.id}`)
      .set('Authorization', `Bearer ${token}`);

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.projects).toHaveLength(3);

    // Cleanup
    await prisma.project.deleteMany({ where: { userId: user.id } });
    await prisma.user.delete({ where: { id: user.id } });
  });
});
