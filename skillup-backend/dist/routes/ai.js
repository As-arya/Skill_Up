"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractJSON = extractJSON;
exports.callHybridAI = callHybridAI;
exports.buildAIAnalysisPrompt = buildAIAnalysisPrompt;
const express_1 = require("express");
const auth_1 = require("../middlewares/auth");
const generative_ai_1 = require("@google/generative-ai");
const prisma_1 = require("../lib/prisma");
const crypto = __importStar(require("crypto"));
const router = (0, express_1.Router)();
// Groq removed as requested. We exclusively use Gemini now.
// ─── Lazy-init Gemini ──────────────────────────────────────
let _genAI = null;
function getGenAI() {
    if (!_genAI) {
        const key = process.env.GEMINI_API_KEY || '';
        console.log('[AI] Initializing Gemini with key:', key ? `${key.substring(0, 8)}...` : 'MISSING!');
        _genAI = new generative_ai_1.GoogleGenerativeAI(key);
    }
    return _genAI;
}
const aiCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
function getCacheKey(endpoint, body) {
    const payload = JSON.stringify({ endpoint, ...body });
    return crypto.createHash('md5').update(payload).digest('hex');
}
function getCachedResult(key) {
    const entry = aiCache.get(key);
    if (!entry)
        return null;
    if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
        aiCache.delete(key);
        return null;
    }
    console.log(`[AI Cache] HIT for key ${key.substring(0, 8)}...`);
    return entry.data;
}
function setCacheResult(key, data) {
    aiCache.set(key, { data, timestamp: Date.now() });
    if (aiCache.size > 100) {
        const oldest = Array.from(aiCache.entries()).sort((a, b) => a[1].timestamp - b[1].timestamp);
        for (let i = 0; i < 20; i++)
            aiCache.delete(oldest[i][0]);
    }
}
// ─── Job Title Sanitization ────────────────────────────────
function sanitizeJobTitle(title) {
    if (!title)
        return title;
    let sanitized = title.trim();
    // Remove common verbose AI prefixes
    const verbosePrefixes = [
        /^The\s+(?:proper|corrected|exact)\s+job\s+title\s+is\s+/i,
        /^The\s+job\s+title\s+(?:is\s+|should\s+be\s+)/i,
        /^Corrected\s+to:\s*/i,
        /^Proper\s+title:\s*/i,
        /^You\s+mean\s+/i,
        /^I\s+think\s+you\s+mean\s+/i,
        /^This\s+should\s+be\s+/i
    ];
    for (const pattern of verbosePrefixes) {
        sanitized = sanitized.replace(pattern, '');
    }
    // Remove trailing descriptions
    // Pattern: "Hotel Manager, which refers to a professional..." or "Hotel Manager - responsible for..."
    const trailingPatterns = [
        /\s*,\s*which\s+refers\s+to.*$/i,
        /\s*,\s*meaning\s+.*$/i,
        /\s*-\s+.*$/,
        /\s*\(.*\)$/,
        /\s*\.\s+.*$/
    ];
    for (const pattern of trailingPatterns) {
        sanitized = sanitized.replace(pattern, '');
    }
    // Capitalize first letter of each word (standard job title format)
    sanitized = sanitized.split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
    return sanitized.trim();
}
// ─── JSON Extraction ───────────────────────────────────────
function extractJSON(text) {
    // First, try to clean up common AI verbose responses
    let cleaned = text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim();
    // Remove any leading/trailing non-JSON text more aggressively
    // Pattern: text before { and after }
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
        cleaned = jsonMatch[0];
    }
    try {
        return JSON.parse(cleaned);
    }
    catch (_) { }
    const startIdx = cleaned.indexOf('{');
    if (startIdx === -1)
        return null;
    let depth = 0;
    for (let i = startIdx; i < cleaned.length; i++) {
        if (cleaned[i] === '{')
            depth++;
        if (cleaned[i] === '}')
            depth--;
        if (depth === 0) {
            try {
                return JSON.parse(cleaned.substring(startIdx, i + 1));
            }
            catch (_) {
                return null;
            }
        }
    }
    return null;
}
// ─── Groq Logic Removed ──────────────────────────────────────
// ─── Gemini Logic (Multimodal) ──────────────────────────────
async function callGeminiWithRetry(prompt, imageBase64, mimeType, cacheKey, maxRetries = 3) {
    const genAI = getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const BASE_DELAY_MS = 2000;
    const parts = [{ text: prompt }];
    if (imageBase64 && mimeType) {
        parts.push({ inlineData: { data: imageBase64, mimeType } });
    }
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            const result = await model.generateContent(parts);
            const text = result.response.text();
            if (cacheKey)
                setCacheResult(cacheKey, text);
            return text;
        }
        catch (err) {
            const isRetryable = err?.status === 429 || err?.status === 503;
            if (isRetryable && attempt < maxRetries) {
                const delay = BASE_DELAY_MS * Math.pow(2, attempt) + Math.random() * 1000;
                console.log(`[Gemini] ${err.status} error. Retrying in ${(delay / 1000).toFixed(1)}s...`);
                await new Promise(r => setTimeout(r, delay));
                continue;
            }
            throw err;
        }
    }
    throw new Error('Gemini max retries exceeded');
}
// ─── AI Routing (Now Gemini Only) ─────────────────────────
async function callHybridAI(params) {
    if (params.cacheKey) {
        const cached = getCachedResult(params.cacheKey);
        if (cached)
            return cached;
    }
    console.log(`[AI] Using Gemini (${params.imageBase64 ? 'Multimodal' : 'Text'})`);
    return callGeminiWithRetry(params.prompt, params.imageBase64, params.mimeType, params.cacheKey);
}
function getErrorMessage(error) {
    if (error?.status === 401 || error?.status === 403)
        return 'API key invalid. Check .env configuration.';
    if (error?.status === 429)
        return 'AI service is busy. Please try again in a few seconds.';
    return 'AI analysis failed. Please try again later.';
}
// ─── Endpoints ──────────────────────────────────────────────
router.post('/cv-check', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, cvText, cvImage, mimeType } = req.body;
        if (!userId || (!cvText && !cvImage)) {
            res.status(400).json({ error: 'userId and content are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        const cacheKey = getCacheKey('cv-check', { userId, text: (cvText || '').substring(0, 200), hasImage: !!cvImage });
        const feedback = await callHybridAI({
            prompt: `Analyze this CV and provide constructive feedback for a software engineer role. Highlight any existing errors, typos, formatting issues, and give actionable advice on how to improve. Format your response cleanly. CV Content: ${cvText || 'Provided as image'}`,
            imageBase64: cvImage,
            mimeType,
            cacheKey
        });
        res.status(200).json({ feedback });
    }
    catch (error) {
        console.error('CV Check Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
// ─── CV Validation ──────────────────────────────────────────
router.post('/validate-cv', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, cvText, cvImage, mimeType } = req.body;
        console.log(`[CV Validation] Request received. userId=${userId}, hasText=${!!cvText}, hasImage=${!!cvImage}, mimeType=${mimeType}`);
        if (!userId || (!cvText && !cvImage)) {
            res.status(400).json({ error: 'userId and content are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        const text = await callHybridAI({
            prompt: `You are a helpful and flexible document classifier. Your job is to determine if the uploaded image or text is a valid professional hiring document (CV, Resume, or Portfolio).

CRITICAL RULES FOR REJECTION ("isCV": false):
1. If the image is a screenshot of a user interface (like a mobile app screen, desktop interface, or random website) without any CV context.
2. If the image is a selfie, meme, landscape, receipt, blank page, or any entirely non-professional document.
3. Do not reject simply because the formatting is plain text.

CRITICAL RULES FOR ACCEPTANCE ("isCV": true):
1. The document appears to be a CV or Resume (lists work experience, education, skills, or basic professional summary).
2. The document is a professional Portfolio (showcases professional projects, design case studies, or developer works).
3. If the content seems to be a legitimate attempt at summarizing a professional background, accept it.

Content: ${cvText || 'Provided as image'}

Respond ONLY with valid JSON containing the boolean "isCV" and a string "reason":
{"isCV": false, "reason": "Explanation of why it is rejected"}
OR
{"isCV": true, "reason": "Explanation of why it is accepted"}`,
            imageBase64: cvImage,
            mimeType
        });
        console.log(`[CV Validation] AI raw response:`, text);
        const data = extractJSON(text);
        console.log(`[CV Validation] Parsed result:`, data);
        res.status(200).json(data || { isCV: false, reason: 'Could not determine document type' });
    }
    catch (error) {
        console.error('[CV Validation] Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
// ─── Job Title Validation ───────────────────────────────────
const KNOWN_JOB_TITLES = [
    // ── Technology & Engineering ──
    'Frontend Developer', 'Backend Developer', 'Full Stack Developer',
    'Full Stack Engineer', 'Software Engineer', 'Mobile Developer',
    'Android Developer', 'iOS Developer', 'Flutter Developer',
    'Web Developer', 'DevOps Engineer', 'Cloud Engineer',
    'Data Scientist', 'Data Analyst', 'Data Engineer',
    'Machine Learning Engineer', 'AI Engineer', 'QA Engineer',
    'Security Engineer', 'Database Administrator', 'Solutions Architect',
    'Technical Lead', 'Game Developer', 'Technical Writer',
    'Embedded Systems Engineer', 'Blockchain Developer', 'Network Engineer',
    'IT Support Specialist', 'Systems Administrator',
    // ── Design & Creative ──
    'UX Designer', 'UI Designer', 'UX/UI Designer', 'Product Designer',
    'Graphic Designer', 'Motion Graphics Designer', 'Illustrator',
    'Interior Designer', 'Fashion Designer', 'Industrial Designer',
    'Video Editor', 'Photographer', 'Animator', 'Art Director',
    'Creative Director', 'Content Creator',
    // ── Business & Management ──
    'Product Manager', 'Project Manager', 'Business Analyst',
    'Management Consultant', 'Operations Manager', 'Supply Chain Manager',
    'Human Resources Manager', 'Recruiter', 'Office Manager',
    'Entrepreneur', 'Business Development Manager', 'Strategy Consultant',
    // ── Marketing & Communications ──
    'Digital Marketing Specialist', 'SEO Specialist', 'Social Media Manager',
    'Content Strategist', 'Copywriter', 'Brand Manager',
    'Public Relations Specialist', 'Marketing Analyst',
    'Email Marketing Specialist', 'Growth Hacker',
    // ── Finance & Accounting ──
    'Financial Analyst', 'Accountant', 'Auditor', 'Investment Banker',
    'Financial Planner', 'Tax Consultant', 'Risk Analyst',
    'Actuary', 'Treasury Analyst',
    // ── Healthcare & Medicine ──
    'Doctor', 'Nurse', 'Pharmacist', 'Dentist', 'Physiotherapist',
    'Medical Laboratory Technologist', 'Public Health Specialist',
    'Clinical Research Coordinator', 'Health Informatics Specialist',
    'Nutritionist',
    // ── Law & Legal ──
    'Lawyer', 'Legal Consultant', 'Paralegal', 'Compliance Officer',
    'Contract Specialist',
    // ── Education & Research ──
    'Teacher', 'Lecturer', 'Education Consultant', 'Research Scientist',
    'Curriculum Developer', 'Academic Advisor', 'Librarian',
    // ── Construction & Architecture ──
    'Civil Engineer', 'Architect', 'Construction Manager',
    'Structural Engineer', 'Urban Planner', 'Quantity Surveyor',
    // ── Media & Journalism ──
    'Journalist', 'News Anchor', 'Podcast Producer', 'Scriptwriter',
    'Film Director', 'Broadcast Engineer',
    // ── Hospitality & Tourism ──
    'Hotel Manager', 'Event Planner', 'Tour Guide', 'Chef',
    'Restaurant Manager',
    // ── Environment & Agriculture ──
    'Environmental Scientist', 'Agricultural Engineer',
    'Sustainability Consultant', 'Wildlife Biologist',
];
router.get('/job-suggestions', auth_1.requireAuth, async (_req, res) => {
    res.status(200).json({ jobs: KNOWN_JOB_TITLES });
});
router.post('/validate-job', auth_1.requireAuth, async (req, res) => {
    try {
        const { jobTitle } = req.body;
        console.log(`[Validation] Received job validation request for: "${jobTitle}"`);
        if (!jobTitle || jobTitle.trim().length < 2) {
            console.log(`[Validation] Job title too short`);
            res.status(400).json({ valid: false, reason: 'Job title is too short' });
            return;
        }
        const normalized = jobTitle.trim().toLowerCase();
        // Quick check against known titles
        const exactMatch = KNOWN_JOB_TITLES.find(j => j.toLowerCase() === normalized);
        if (exactMatch) {
            console.log(`[Validation] Exact match found: ${exactMatch}`);
            res.status(200).json({ valid: true, corrected: exactMatch });
            return;
        }
        // Fuzzy match: check if any known title contains the input or vice versa
        const fuzzyMatch = KNOWN_JOB_TITLES.find(j => j.toLowerCase().includes(normalized) || normalized.includes(j.toLowerCase()));
        if (fuzzyMatch) {
            console.log(`[Validation] Fuzzy match found: ${fuzzyMatch}`);
            res.status(200).json({ valid: true, corrected: fuzzyMatch });
            return;
        }
        // Use AI as fallback for creative but valid job titles
        console.log(`[Validation] Calling AI fallback for: "${jobTitle}"`);
        const text = await callHybridAI({
            prompt: `Is "${jobTitle}" a valid, real job position or role in any professional field?

CRITICAL INSTRUCTIONS:
1. If it IS a valid job title, respond with EXACTLY: {"valid": true, "corrected": "EXACT_JOB_TITLE_HERE"}
2. The "corrected" field MUST contain ONLY the exact job title name (e.g., "Hotel Manager"). 
3. DO NOT include any sentences, descriptions, or explanations in the "corrected" field.
4. DO NOT use phrases like "The proper/corrected job title is" or "which refers to".
5. If you need to correct the job title, use the most standard/common version.

If it is NOT a valid job title (nonsense, gibberish), respond with: {"valid": false, "reason": "Brief explanation", "suggestions": ["Suggested job 1", "Suggested job 2", "Suggested job 3"]}

Respond ONLY with valid JSON. Do not include any other text.`
        });
        console.log(`[Validation] AI raw text:`, text);
        const data = extractJSON(text);
        console.log(`[Validation] Extracted JSON:`, data);
        // Sanitize the corrected field if it contains verbose text
        if (data && data.valid === true && data.corrected) {
            const corrected = data.corrected.toString();
            // Extract just the job title if AI returned verbose text
            // Pattern: "The proper/corrected job title is X, which refers to..."
            const match = corrected.match(/^(?:The\s+(?:proper|corrected)\s+job\s+title\s+is\s+)?([^,\.]+?)(?:\s*,\s*which\s+refers\s+to|\s*\.|$)/i);
            if (match && match[1]) {
                data.corrected = match[1].trim();
                console.log(`[Validation] Sanitized corrected field from "${corrected}" to "${data.corrected}"`);
            }
        }
        res.status(200).json(data || { valid: false, reason: 'Could not validate job title' });
    }
    catch (error) {
        console.error('[Validation] Job Validation Error:', error?.message || error);
        // On error, allow through rather than blocking
        res.status(200).json({ valid: true, corrected: req.body.jobTitle });
    }
});
router.post('/extract-cv', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, cvText, cvImage, mimeType } = req.body;
        if (!userId || (!cvText && !cvImage)) {
            res.status(400).json({ error: 'userId and content are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        const cacheKey = getCacheKey('extract-cv-v2', { userId, text: (cvText || '').substring(0, 200), hasImage: !!cvImage });
        const text = await callHybridAI({
            prompt: `Extract the candidate's top 5 best technical skills and their exact Target Role. Look for explicit role titles written in the document (e.g., "Software Engineer", "Frontend Developer"). Do not guess a narrower role if a broader one is explicitly stated in the title or header. Respond ONLY with valid JSON: {"topSkills": ["skill1"], "targetRole": "Exact Role Title"}. Content: ${cvText || 'Provided as image'}`,
            imageBase64: cvImage,
            mimeType,
            cacheKey
        });
        const data = extractJSON(text);
        res.status(200).json(data || { topSkills: [], targetRole: 'Unknown' });
    }
    catch (error) {
        console.error('Extract CV Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
function buildAIAnalysisPrompt(jobTitle, cvText, projects) {
    const projectSummaries = projects.map(p => `- ${p.title}: ${p.description} (Tags: ${typeof p.tags === 'string' ? p.tags : JSON.stringify(p.tags)})`).join('\n');
    return `You are a career skills analyst. Analyze the candidate's CV and projects against the target role.
Target Role: "${jobTitle}"

Scoring Rules:
- CV Claim: Max 40% if skill is only mentioned in the CV.
- Project Evidence: Up to 40% if skill is actively used in the provided projects.
- Complexity/Depth: Up to 20% based on project descriptions.

CV Content: ${cvText || 'Provided as image'}

Projects Data:
${projects.length > 0 ? projectSummaries : 'No verified projects provided.'}

Instructions:
1. Identify 3-6 skill GROUPS that the candidate needs to improve for the target role (e.g., "UX Design Experience", "Backend Development", "Project Management").
2. For each group, list 2-4 specific sub-skills that need improvement.
3. For each group, estimate a completion percentage (0-100) based on existing evidence.
4. Also identify skills the candidate already masters well.
5. Provide a "cvFeedback" section that contains:
   - "strengths": An array of 2-4 specific positive things about the CV for the target role (what the candidate does well).
   - "weaknesses": An array of 2-4 specific areas where the CV is lacking or could be improved for the target role.
   These should be concise 1-sentence actionable insights.

Respond ONLY with valid JSON in this exact format:
{
  "matchScore": 72,
  "skillGaps": [
    { "group": "UX Design Experience", "percentage": 66, "subSkills": ["User Research", "Wireframing", "High-fidelity UI"] },
    { "group": "Project Management", "percentage": 50, "subSkills": ["Agile Methodology", "Sprint Planning"] }
  ],
  "masteredSkills": ["HTML/CSS", "Flutter", "JavaScript"],
  "cvFeedback": {
    "strengths": ["Strong foundation in mobile development with Flutter projects", "Demonstrated database optimization skills"],
    "weaknesses": ["No evidence of CI/CD pipeline experience", "Lacks frontend testing or TDD methodology"]
  }
}`;
}
router.post('/match', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, roleDescription, cvContent, cvImage, mimeType } = req.body;
        if (!userId || !roleDescription) {
            res.status(400).json({ error: 'userId and roleDescription are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        const projects = await prisma_1.prisma.project.findMany({ where: { userId } });
        const prompt = buildAIAnalysisPrompt(roleDescription, cvContent, projects);
        const cacheKey = getCacheKey('match-evidenced', { userId, roleDescription, hasImage: !!cvImage });
        const text = await callHybridAI({
            prompt,
            imageBase64: cvImage,
            mimeType,
            cacheKey
        });
        const data = extractJSON(text);
        console.log('[AI Match Result]:', JSON.stringify(data, null, 2));
        const result = data || { matchScore: 0, skillGaps: [], masteredSkills: [] };
        // Auto-save skill gaps as unchecked skills grouped by category
        if (result.skillGaps && Array.isArray(result.skillGaps)) {
            for (const gap of result.skillGaps) {
                const groupName = gap.group || 'General';
                const subSkills = gap.subSkills || [];
                for (const subSkill of subSkills) {
                    const existing = await prisma_1.prisma.skill.findFirst({ where: { userId, name: subSkill } });
                    if (!existing) {
                        await prisma_1.prisma.skill.create({
                            data: { userId, name: subSkill, category: groupName, isChecked: false }
                        });
                    }
                    else if (existing.category === 'HARD' || existing.category === 'SOFT') {
                        // Update legacy category to the new group name
                        await prisma_1.prisma.skill.update({ where: { id: existing.id }, data: { category: groupName } });
                    }
                }
            }
        }
        // Auto-save mastered skills
        if (result.masteredSkills && Array.isArray(result.masteredSkills)) {
            for (const skillName of result.masteredSkills) {
                const existing = await prisma_1.prisma.skill.findFirst({ where: { userId, name: skillName } });
                if (!existing) {
                    await prisma_1.prisma.skill.create({
                        data: { userId, name: skillName, category: 'Mastered', isChecked: true }
                    });
                }
                else if (!existing.isChecked) {
                    await prisma_1.prisma.skill.update({ where: { id: existing.id }, data: { isChecked: true } });
                }
            }
        }
        res.status(200).json(result);
    }
    catch (error) {
        console.error('Match Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
router.post('/portfolio', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, jobTitle, content, portfolioImage, mimeType } = req.body;
        if (!userId || (!content && !portfolioImage)) {
            res.status(400).json({ error: 'userId and content are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        // Fetch user's existing skills so the AI can identify which ones are proven
        const userSkills = await prisma_1.prisma.skill.findMany({ where: { userId }, select: { name: true } });
        const skillNames = userSkills.map(s => s.name);
        const cacheKey = getCacheKey('portfolio-v2', { userId, jobTitle, hasImage: !!portfolioImage });
        const text = await callHybridAI({
            prompt: `Analyze this portfolio for the "${jobTitle}" role.

Portfolio Content: ${content || 'Provided as image'}

The user currently tracks these skills: ${JSON.stringify(skillNames)}

Instructions:
1. Score the portfolio (0-100) for the target role.
2. Provide constructive feedback grouped into 'strengths', 'weaknesses', and 'improvements' (each as an array of strings).
3. Identify which of the user's tracked skills are PROVEN/DEMONSTRATED by this portfolio. Only include skills where there is clear evidence.

Respond ONLY with valid JSON:
{
  "matchScore": 75,
  "cvFeedback": {
    "strengths": ["...", "..."],
    "weaknesses": ["...", "..."],
    "improvements": ["...", "..."]
  },
  "masteredSkills": ["HTML/CSS", "Flutter"]
}`,
            imageBase64: portfolioImage,
            mimeType,
            cacheKey
        });
        const data = extractJSON(text);
        const result = data || { matchScore: 0, cvFeedback: { strengths: [], weaknesses: [], improvements: [] }, masteredSkills: [] };
        // Auto-save mastered skills
        if (result.masteredSkills && Array.isArray(result.masteredSkills)) {
            for (const skillName of result.masteredSkills) {
                const existing = await prisma_1.prisma.skill.findFirst({ where: { userId, name: skillName } });
                if (!existing) {
                    await prisma_1.prisma.skill.create({
                        data: { userId, name: skillName, category: 'General', isChecked: true }
                    });
                }
                else if (!existing.isChecked) {
                    await prisma_1.prisma.skill.update({ where: { id: existing.id }, data: { isChecked: true } });
                }
            }
        }
        res.status(200).json(result);
    }
    catch (error) {
        console.error('Portfolio Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
// SSRF Security validation helper
function isValidPublicUrl(input) {
    try {
        const url = new URL(input);
        if (url.protocol !== 'http:' && url.protocol !== 'https:')
            return false;
        const hostname = url.hostname;
        // Block localhost, private IPs, loopback
        if (hostname === 'localhost' ||
            hostname === '127.0.0.1' ||
            hostname.startsWith('10.') ||
            hostname.startsWith('192.168.') ||
            hostname.match(/^172\.(1[6-9]|2[0-9]|3[0-1])\./) ||
            hostname.includes('internal') ||
            hostname.includes('aws') ||
            hostname.includes('metadata')) {
            return false;
        }
        return true;
    }
    catch {
        return false;
    }
}
router.post('/portfolio/scrape', auth_1.requireAuth, async (req, res) => {
    try {
        const { userId, jobTitle, url } = req.body;
        if (!userId || !jobTitle || !url) {
            res.status(400).json({ error: 'userId, jobTitle, and url are required' });
            return;
        }
        if (req.user?.userId !== userId) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        if (!isValidPublicUrl(url)) {
            res.status(400).json({ error: 'Invalid or blocked URL. Only public HTTP/HTTPS URLs are allowed for security reasons.' });
            return;
        }
        const jinaUrl = `https://r.jina.ai/${encodeURIComponent(url)}`;
        const response = await fetch(jinaUrl, {
            headers: {
                'Accept': 'text/plain',
                'User-Agent': 'SkillUp-App'
            }
        });
        if (!response.ok) {
            res.status(response.status).json({ error: 'Failed to scrape the provided portfolio URL' });
            return;
        }
        const markdown = await response.text();
        const userSkills = await prisma_1.prisma.skill.findMany({ where: { userId }, select: { name: true } });
        const skillNames = userSkills.map(s => s.name);
        const cacheKey = getCacheKey('portfolio-scrape-v2', { userId, jobTitle, url });
        const text = await callHybridAI({
            prompt: `Analyze portfolio for "${jobTitle}" role. Score (0-100) and feedback. Extracted Markdown Content: ${markdown.substring(0, 50000)}. The user currently tracks these skills: ${JSON.stringify(skillNames)}. Identify which of these tracked skills are PROVEN by this portfolio. Respond ONLY JSON: {"matchScore": 0, "cvFeedback": {"strengths": [], "weaknesses": [], "improvements": []}, "masteredSkills": []}`,
            cacheKey
        });
        const data = extractJSON(text);
        const result = data || { matchScore: 0, cvFeedback: { strengths: [], weaknesses: [], improvements: [] }, masteredSkills: [] };
        // Auto-save mastered skills
        if (result.masteredSkills && Array.isArray(result.masteredSkills)) {
            for (const skillName of result.masteredSkills) {
                const existing = await prisma_1.prisma.skill.findFirst({ where: { userId, name: skillName } });
                if (!existing) {
                    await prisma_1.prisma.skill.create({
                        data: { userId, name: skillName, category: 'General', isChecked: true }
                    });
                }
                else if (!existing.isChecked) {
                    await prisma_1.prisma.skill.update({ where: { id: existing.id }, data: { isChecked: true } });
                }
            }
        }
        res.status(200).json(result);
    }
    catch (error) {
        console.error('Portfolio Scrape Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
exports.default = router;
