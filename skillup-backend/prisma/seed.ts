import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  console.log("Seeding database...");

  // 1. Create demo user
  const hashedPassword = await bcrypt.hash("password123", 10);

  const user = await prisma.user.upsert({
    where: { email: "alex@example.com" },
    update: {},
    create: {
      name: "Alex Johnson",
      email: "alex@example.com",
      password: hashedPassword,
    },
  });

  console.log(`User created: ${user.name} (${user.email})`);

  // 2. Seed default skills
  const hardSkills = [
    { name: "React.js", isChecked: true },
    { name: "TypeScript", isChecked: true },
    { name: "Node.js", isChecked: false },
    { name: "Python", isChecked: true },
    { name: "SQL/Database", isChecked: false },
    { name: "Git & GitHub", isChecked: true },
    { name: "REST APIs", isChecked: false },
  ];

  const softSkills = [
    { name: "Communication", isChecked: true },
    { name: "Teamwork", isChecked: true },
    { name: "Problem Solving", isChecked: true },
    { name: "Time Management", isChecked: false },
    { name: "Leadership", isChecked: false },
  ];

  for (const skill of hardSkills) {
    await prisma.skill.upsert({
      where: { userId_name: { userId: user.id, name: skill.name } },
      update: { isChecked: skill.isChecked },
      create: {
        userId: user.id,
        name: skill.name,
        category: "General",
        isChecked: skill.isChecked,
      },
    });
  }

  for (const skill of softSkills) {
    await prisma.skill.upsert({
      where: { userId_name: { userId: user.id, name: skill.name } },
      update: { isChecked: skill.isChecked },
      create: {
        userId: user.id,
        name: skill.name,
        category: "General",
        isChecked: skill.isChecked,
      },
    });
  }

  console.log(`Skills seeded: ${hardSkills.length} hard + ${softSkills.length} soft`);

  // 3. Seed sample projects
  const projects = [
    {
      title: "E-Commerce Platform",
      description:
        "Full-stack e-commerce solution with React, Node.js, and PostgreSQL. Features include user authentication, shopping cart, and payment integration.",
      tags: JSON.stringify(["React", "Node.js", "PostgreSQL", "Stripe"]),
      links: [
        { type: "GitHub", url: "https://github.com/alex/ecommerce" },
        { type: "Demo", url: "https://ecommerce-demo.vercel.app" },
      ],
    },
    {
      title: "Task Management App",
      description:
        "Real-time collaborative task manager built with React and Firebase. Supports team workspaces and notifications.",
      tags: JSON.stringify(["React", "Firebase", "Tailwind CSS"]),
      links: [
        { type: "GitHub", url: "https://github.com/alex/taskmanager" },
        { type: "Demo", url: "https://taskmanager-demo.vercel.app" },
      ],
    },
    {
      title: "Weather Dashboard",
      description:
        "Weather forecasting dashboard using OpenWeather API with interactive charts and location-based predictions.",
      tags: JSON.stringify(["TypeScript", "Next.js", "Chart.js", "API"]),
      links: [{ type: "GitHub", url: "https://github.com/alex/weather" }],
    },
    {
      title: "Portfolio Website",
      description:
        "Personal portfolio showcasing projects and skills with smooth animations and responsive design.",
      tags: JSON.stringify(["React", "Motion", "Tailwind CSS"]),
      links: [{ type: "Demo", url: "https://alex-portfolio.vercel.app" }],
    },
  ];

  // Delete existing projects for this user to avoid duplicates on re-seed
  await prisma.project.deleteMany({ where: { userId: user.id } });

  for (const project of projects) {
    await prisma.project.create({
      data: {
        userId: user.id,
        title: project.title,
        description: project.description,
        tags: project.tags,
        links: {
          create: project.links,
        },
      },
    });
  }

  console.log(`Projects seeded: ${projects.length}`);

  // 4. Seed learning targets
  await prisma.learningTarget.deleteMany({ where: { userId: user.id } });

  const targets = [
    { skillName: "TypeScript", targetMinutes: 30, isCompleted: false },
    { skillName: "Node.js", targetMinutes: 45, isCompleted: false },
    { skillName: "SQL/Database", targetMinutes: 30, isCompleted: false },
  ];

  for (const target of targets) {
    await prisma.learningTarget.create({
      data: { userId: user.id, ...target },
    });
  }

  console.log(`Learning targets seeded: ${targets.length}`);
  console.log("\nSeed completed successfully!");
  console.log("   Demo credentials: alex@example.com / password123");
}

main()
  .catch((e) => {
    console.error("Seed failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
