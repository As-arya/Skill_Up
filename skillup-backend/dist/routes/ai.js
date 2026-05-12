"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildAIAnalysisPrompt = buildAIAnalysisPrompt;
const express_1 = require("express");
const auth_1 = require("../middlewares/auth");
const groq_sdk_1 = __importDefault(require("groq-sdk"));
const generative_ai_1 = require("@google/generative-ai");
const prisma_1 = require("../lib/prisma");
const crypto_1 = __importDefault(require("crypto"));
const router = (0, express_1.Router)();
// ─── Lazy-init Groq ────────────────────────────────────────
let _groq = null;
function getGroq() {
    if (!_groq) {
        const key = process.env.GROQ_API_KEY || '';
        console.log('[AI] Initializing Groq with key:', key ? `${key.substring(0, 8)}...` : 'MISSING!');
        _groq = new groq_sdk_1.default({ apiKey: key });
    }
    return _groq;
}
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
    return crypto_1.default.createHash('md5').update(payload).digest('hex');
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
        const oldest = [...aiCache.entries()].sort((a, b) => a[1].timestamp - b[1].timestamp);
        for (let i = 0; i < 20; i++)
            aiCache.delete(oldest[i][0]);
    }
}
// ─── JSON Extraction ───────────────────────────────────────
function extractJSON(text) {
    let cleaned = text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim();
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
// ─── Groq Logic (Text) ─────────────────────────────────────
async function callGroqWithRetry(prompt, cacheKey, maxRetries = 3) {
    const groq = getGroq();
    const BASE_DELAY_MS = 2000;
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            const chatCompletion = await groq.chat.completions.create({
                messages: [{ role: 'user', content: prompt }],
                model: 'llama-3.3-70b-versatile',
            });
            const text = chatCompletion.choices[0]?.message?.content || '';
            if (cacheKey)
                setCacheResult(cacheKey, text);
            return text;
        }
        catch (err) {
            const isRetryable = err?.status === 429 || err?.status === 503 || err?.status === 529;
            if (isRetryable && attempt < maxRetries) {
                const delay = BASE_DELAY_MS * Math.pow(2, attempt) + Math.random() * 1000;
                console.log(`[Groq] ${err.status} error. Retrying in ${(delay / 1000).toFixed(1)}s...`);
                await new Promise(r => setTimeout(r, delay));
                continue;
            }
            throw err;
        }
    }
    throw new Error('Groq max retries exceeded');
}
// ─── Gemini Logic (Multimodal) ──────────────────────────────
async function callGeminiWithRetry(prompt, imageBase64, mimeType, cacheKey, maxRetries = 3) {
    const genAI = getGenAI();
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
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
// ─── Hybrid Routing ────────────────────────────────────────
async function callHybridAI(params) {
    if (params.cacheKey) {
        const cached = getCachedResult(params.cacheKey);
        if (cached)
            return cached;
    }
    if (params.imageBase64) {
        console.log('[AI] Using Gemini (Multimodal)');
        return callGeminiWithRetry(params.prompt, params.imageBase64, params.mimeType, params.cacheKey);
    }
    else {
        console.log('[AI] Using Groq (Text)');
        return callGroqWithRetry(params.prompt, params.cacheKey);
    }
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
            prompt: `Analyze this CV and provide constructive feedback for a software engineer role. Be concise but helpful. CV Content: ${cvText || 'Provided as image'}`,
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
        const cacheKey = getCacheKey('extract-cv', { userId, text: (cvText || '').substring(0, 200), hasImage: !!cvImage });
        const text = await callHybridAI({
            prompt: `Extract candidate's top 5 best technical skills and target role. Respond ONLY JSON: {"topSkills": [], "targetRole": ""}. CV Content: ${cvText || 'Provided as image'}`,
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
    return `Calculate skill proficiency based on Evidence. Role: "${jobTitle}".
CV Claim: Max 40% if skill is only mentioned in the CV.
Project Evidence: Up to 40% if skill is actively used in the provided projects.
Complexity/Depth: Up to 20% based on project descriptions.

CV Content: ${cvText || 'Provided as image'}

Projects Data:
${projects.length > 0 ? projectSummaries : 'No verified projects provided.'}

Respond ONLY JSON: {"matchScore": 0, "skillGaps": ["gap1", "gap2"]}`;
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
        res.status(200).json(data || { matchScore: 0, skillGaps: [] });
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
        const cacheKey = getCacheKey('portfolio', { userId, jobTitle, hasImage: !!portfolioImage });
        const text = await callHybridAI({
            prompt: `Analyze portfolio for "${jobTitle}" role. Score (0-100) and feedback. Content: ${content || 'Provided as image'}. Respond ONLY JSON: {"matchScore": 0, "cvFeedback": []}`,
            imageBase64: portfolioImage,
            mimeType,
            cacheKey
        });
        const data = extractJSON(text);
        res.status(200).json(data || { matchScore: 0, cvFeedback: [] });
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
        const cacheKey = getCacheKey('portfolio-scrape', { userId, jobTitle, url });
        const text = await callHybridAI({
            prompt: `Analyze portfolio for "${jobTitle}" role. Score (0-100) and feedback. Extracted Markdown Content: ${markdown.substring(0, 50000)}. Respond ONLY JSON: {"matchScore": 0, "cvFeedback": []}`,
            cacheKey
        });
        const data = extractJSON(text);
        res.status(200).json(data || { matchScore: 0, cvFeedback: [] });
    }
    catch (error) {
        console.error('Portfolio Scrape Error:', error?.message || error);
        res.status(500).json({ error: getErrorMessage(error) });
    }
});
exports.default = router;
