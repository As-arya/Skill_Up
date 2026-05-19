"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const auth_1 = __importDefault(require("./routes/auth"));
const dashboard_1 = __importDefault(require("./routes/dashboard"));
const skills_1 = __importDefault(require("./routes/skills"));
const projects_1 = __importDefault(require("./routes/projects"));
const learning_targets_1 = __importDefault(require("./routes/learning-targets"));
const profile_1 = __importDefault(require("./routes/profile"));
const ai_1 = __importDefault(require("./routes/ai"));
const app = (0, express_1.default)();
const port = process.env.PORT || 3000;
app.use((0, cors_1.default)());
app.use(express_1.default.json({ limit: '50mb' }));
app.use(express_1.default.urlencoded({ limit: '50mb', extended: true }));
// Routes
app.use('/api', auth_1.default);
app.use('/api/dashboard', dashboard_1.default);
app.use('/api/skills', skills_1.default);
app.use('/api/projects', projects_1.default);
app.use('/api/learning-targets', learning_targets_1.default);
app.use('/api/profile', profile_1.default);
app.use('/api', ai_1.default);
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});
app.listen(Number(port), '0.0.0.0', () => {
    console.log(`[server]: Server is running at http://0.0.0.0:${port}`);
    console.log(`[server]: Accessible from Android emulator at http://10.0.2.2:${port}`);
});
