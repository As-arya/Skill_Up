import { buildAIAnalysisPrompt } from '../src/routes/ai';

describe('Evidence-Based Scoring Prompt Builder', () => {
  it('should include project data in the prompt to adjust scores', () => {
    const jobTitle = 'Frontend Developer';
    const cvText = 'I am a frontend developer skilled in React and TypeScript.';
    const projects = [
      { title: 'E-commerce App', description: 'Built with React, Redux, and TypeScript', tags: ['React', 'TypeScript'] }
    ];

    const prompt = buildAIAnalysisPrompt(jobTitle, cvText, projects);

    expect(prompt).toContain('React');
    expect(prompt).toContain('E-commerce App');
    expect(prompt).toContain('Calculate skill proficiency based on Evidence');
    expect(prompt).toContain('CV Claim: Max 40%');
    expect(prompt).toContain('Project Evidence: Up to 40%');
    expect(prompt).toContain('Complexity/Depth: Up to 20%');
  });

  it('should work without projects', () => {
    const jobTitle = 'Frontend Developer';
    const cvText = 'I am a frontend developer skilled in React and TypeScript.';
    const projects: any[] = [];

    const prompt = buildAIAnalysisPrompt(jobTitle, cvText, projects);

    expect(prompt).toContain('React');
    expect(prompt).toContain('No verified projects provided');
  });
});
