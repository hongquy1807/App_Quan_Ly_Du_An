const express = require('express');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');

const router = express.Router();

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

const JWT_SECRET = process.env.JWT_SECRET || 'quanlyduan-dev-secret';
const DEFAULT_GEMINI_MODEL = 'models/gemini-3.6-flash';
const GEMINI_MODEL = process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;
let cachedGeminiModels = null;

function getBearerToken(req) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return null;
    return authHeader.slice(7).trim();
}

function requireAuth(req, res, next) {
    try {
        const token = getBearerToken(req);
        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Báº¡n chÆ°a Ä‘Äƒng nháº­p.'
            });
        }

        req.user = jwt.verify(token, JWT_SECRET);
        next();
    } catch (err) {
        return res.status(401).json({
            success: false,
            message: 'PhiĂªn Ä‘Äƒng nháº­p khĂ´ng há»£p lá»‡ hoáº·c Ä‘Ă£ háº¿t háº¡n.'
        });
    }
}

function stripCodeFence(text) {
    return text
        .replace(/^```(?:json)?/i, '')
        .replace(/```$/i, '')
        .trim();
}

function safeParseJson(text) {
    try {
        return JSON.parse(stripCodeFence(text));
    } catch (err) {
        const match = text.match(/\{[\s\S]*\}/);
        if (!match) return null;
        try {
            return JSON.parse(match[0]);
        } catch (_) {
            return null;
        }
    }
}

async function callGemini(prompt, { temperature = 0.2 } = {}) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        throw new Error('Thiếu GEMINI_API_KEY trong biến môi trường backend.');
    }

    const models = await resolveGeminiModels(apiKey);
    let lastError = null;

    for (const model of models) {
        const url = `https://generativelanguage.googleapis.com/v1beta/${model}:generateContent?key=${apiKey}`;
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [
                    {
                        role: 'user',
                        parts: [{ text: prompt }]
                    }
                ],
                generationConfig: {
                    temperature,
                    topP: 0.9,
                    maxOutputTokens: 1024
                }
            })
        });

        const data = await response.json();
        if (response.ok) {
            console.log(`Gemini model đang dùng: ${model}`);
            return data.candidates?.[0]?.content?.parts?.map((part) => part.text).join('\n').trim() || '';
        }

        const message = data.error?.message || 'Không thể gọi Gemini API.';
        lastError = new Error(message);
        if (!isRetryableGeminiError(response.status, message)) {
            throw lastError;
        }

        console.warn(`Gemini model ${model} lỗi tạm thời, thử model khác: ${message}`);
    }

    throw lastError || new Error('Không thể gọi Gemini API.');
}

function normalizeGeminiModelName(model) {
    const value = String(model || '').trim();
    if (!value) return '';
    return value.startsWith('models/') ? value : `models/${value}`;
}

function isRetryableGeminiError(status, message) {
    const text = String(message || '').toLowerCase();
    return status === 404 ||
        status === 429 ||
        status === 503 ||
        text.includes('high demand') ||
        text.includes('no longer available') ||
        text.includes('not found') ||
        text.includes('overloaded') ||
        text.includes('temporarily') ||
        text.includes('try again later');
}

async function fetchAvailableGeminiModels(apiKey) {
    const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`
    );
    const data = await response.json();
    if (!response.ok) {
        const message = data.error?.message || 'Không thể lấy danh sách Gemini models.';
        throw new Error(message);
    }

    const models = Array.isArray(data.models) ? data.models : [];
    const generativeModels = models.filter((model) => {
        const methods = model.supportedGenerationMethods || [];
        return methods.includes('generateContent') &&
            !model.name.includes('image') &&
            !model.name.includes('embedding');
    });

    const preferred = generativeModels.find((model) => model.name.includes('flash')) || generativeModels[0];
    if (!preferred?.name) {
        throw new Error('Không tìm thấy Gemini model nào hỗ trợ generateContent cho API key này.');
    }

    return generativeModels
        .map((model) => model.name)
        .sort((a, b) => {
            const aFlash = a.includes('flash') ? 0 : 1;
            const bFlash = b.includes('flash') ? 0 : 1;
            return aFlash - bFlash || a.localeCompare(b);
        });
}

async function resolveGeminiModels(apiKey) {
    const configuredModels = [
        GEMINI_MODEL,
        ...(process.env.GEMINI_FALLBACK_MODELS || '').split(',')
    ]
        .map(normalizeGeminiModelName)
        .filter(Boolean);

    if (!cachedGeminiModels) {
        try {
            cachedGeminiModels = await fetchAvailableGeminiModels(apiKey);
        } catch (err) {
            console.warn(`Không thể lấy danh sách Gemini models, dùng model cấu hình: ${err.message}`);
            cachedGeminiModels = [];
        }
    }

    return [...new Set([...configuredModels, ...cachedGeminiModels])];
}
function fallbackIntent(question) {
    const q = question.toLowerCase();
    if (q.includes('quĂ¡ háº¡n') || q.includes('trá»… háº¡n')) {
        return { intent: 'find_overdue_tasks', retrieval_type: 'sql', entities: {} };
    }
    if (q.includes('task') || q.includes('nhiá»‡m vá»¥')) {
        if (q.includes('cá»§a tĂ´i') || q.includes('tĂ´i')) {
            return { intent: 'list_my_tasks', retrieval_type: 'sql', entities: {} };
        }
        return { intent: 'project_summary', retrieval_type: 'sql', entities: {} };
    }
    if (q.includes('thĂ nh viĂªn') || q.includes('ai tham gia')) {
        return { intent: 'project_members', retrieval_type: 'sql', entities: {} };
    }
    return { intent: 'general_help', retrieval_type: 'none', entities: {} };
}

async function parseIntent(question) {
    const prompt = `
Báº¡n lĂ  bá»™ phĂ¢n tĂ­ch cĂ¢u há»i cho á»©ng dá»¥ng quáº£n lĂ½ dá»± Ă¡n.
HĂ£y tráº£ vá» JSON duy nháº¥t, khĂ´ng markdown.

CĂ¡c intent há»£p lá»‡:
- list_my_tasks: user há»i cĂ¡c task/nhiá»‡m vá»¥ cá»§a báº£n thĂ¢n
- find_overdue_tasks: user há»i task quĂ¡ háº¡n/trá»… háº¡n
- count_incomplete_tasks: user há»i sá»‘ task chÆ°a hoĂ n thĂ nh
- project_summary: user há»i tĂ³m táº¯t/tĂ¬nh hĂ¬nh dá»± Ă¡n
- project_members: user há»i thĂ nh viĂªn dá»± Ă¡n
- general_help: cĂ¢u há»i chung, chÆ°a cáº§n truy váº¥n database

Schema JSON:
{
  "intent": "intent_name",
  "retrieval_type": "sql|none",
  "entities": {
    "project_name": "tĂªn dá»± Ă¡n náº¿u cĂ³"
  }
}

CĂ¢u há»i: ${question}
`;

    try {
        const text = await callGemini(prompt, { temperature: 0 });
        const parsed = safeParseJson(text);
        if (parsed?.intent) {
            return {
                intent: parsed.intent,
                retrieval_type: parsed.retrieval_type || 'sql',
                entities: parsed.entities || {}
            };
        }
    } catch (err) {
        console.warn('KhĂ´ng thá»ƒ phĂ¢n tĂ­ch intent báº±ng Gemini, dĂ¹ng fallback:', err.message);
    }

    return fallbackIntent(question);
}

function projectFilterSql(projectName, params) {
    if (!projectName) return '';
    params.push(`%${projectName}%`);
    return ' AND p.name LIKE ?';
}

async function retrieveSqlContext(intentResult, userId) {
    const intent = intentResult.intent;
    const projectName = intentResult.entities?.project_name?.trim();

    if (intent === 'general_help') {
        return {
            type: 'general',
            rows: [],
            summary: 'NgÆ°á»i dĂ¹ng há»i cĂ¢u há»i chung vá» quáº£n lĂ½ dá»± Ă¡n.'
        };
    }

    if (intent === 'list_my_tasks') {
        const params = [userId, userId];
        const [rows] = await pool.query(
            `SELECT
                    t.id,
                    t.title,
                    t.description,
                    t.status,
                    t.due_date,
                    p.id AS project_id,
                    p.name AS project_name
             FROM tasks t
             INNER JOIN projects p ON p.id = t.project_id
             INNER JOIN project_members pm ON pm.project_id = p.id
             WHERE pm.user_id = ?
               AND p.status <> 'completed'
               AND (t.assignee_id = ? OR t.assignee_id IS NULL)
               AND COALESCE(t.status, 'todo') <> 'done'
             ORDER BY t.due_date IS NULL, t.due_date ASC, t.id DESC
             LIMIT 30`,
            params
        );
        return { type: intent, rows };
    }

    if (intent === 'find_overdue_tasks') {
        const params = [userId, userId];
        const filter = projectFilterSql(projectName, params);
        const [rows] = await pool.query(
            `SELECT
                    t.id,
                    t.title,
                    t.status,
                    t.due_date,
                    p.id AS project_id,
                    p.name AS project_name,
                    COALESCE(u.name, 'Cáº£ team') AS assignee_name
             FROM tasks t
             INNER JOIN projects p ON p.id = t.project_id
             INNER JOIN project_members pm ON pm.project_id = p.id
             LEFT JOIN users u ON u.id = t.assignee_id
             WHERE pm.user_id = ?
               AND p.status <> 'completed'
               AND (t.assignee_id = ? OR t.assignee_id IS NULL)
               AND COALESCE(t.status, 'todo') <> 'done'
               AND t.due_date IS NOT NULL
               AND t.due_date < CURDATE()
               ${filter}
             ORDER BY t.due_date ASC, t.id DESC
             LIMIT 30`,
            params
        );
        return { type: intent, rows };
    }

    if (intent === 'count_incomplete_tasks') {
        const params = [userId];
        const filter = projectFilterSql(projectName, params);
        const [rows] = await pool.query(
            `SELECT
                    p.id AS project_id,
                    p.name AS project_name,
                    COUNT(t.id) AS incomplete_tasks
             FROM projects p
             INNER JOIN project_members pm ON pm.project_id = p.id
             LEFT JOIN tasks t
                ON t.project_id = p.id
               AND COALESCE(t.status, 'todo') <> 'done'
             WHERE pm.user_id = ?
               AND p.status <> 'completed'
               ${filter}
             GROUP BY p.id, p.name
             ORDER BY incomplete_tasks DESC, p.name ASC
             LIMIT 20`,
            params
        );
        return { type: intent, rows };
    }

    if (intent === 'project_members') {
        const params = [userId];
        const filter = projectFilterSql(projectName, params);
        const [rows] = await pool.query(
            `SELECT
                    p.id AS project_id,
                    p.name AS project_name,
                    u.name AS member_name,
                    u.email,
                    COALESCE(pr.name, 'ThĂ nh viĂªn') AS role_name
             FROM projects p
             INNER JOIN project_members current_member
                ON current_member.project_id = p.id AND current_member.user_id = ?
             INNER JOIN project_members pm ON pm.project_id = p.id
             INNER JOIN users u ON u.id = pm.user_id
             LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
             WHERE p.status <> 'completed'
               ${filter}
             ORDER BY p.name ASC, pm.project_role_id ASC, u.name ASC
             LIMIT 80`,
            params
        );
        return { type: intent, rows };
    }
    

    const params = [userId];
    const filter = projectFilterSql(projectName, params);
    const [rows] = await pool.query(
        `SELECT
                p.id AS project_id,
                p.name AS project_name,
                p.description,
                p.status,
                COUNT(DISTINCT pm_all.user_id) AS member_count,
                COUNT(DISTINCT t.id) AS total_tasks,
                SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) AS completed_tasks,
                SUM(CASE WHEN COALESCE(t.status, 'todo') <> 'done' THEN 1 ELSE 0 END) AS incomplete_tasks,
                SUM(CASE WHEN COALESCE(t.status, 'todo') <> 'done'
                          AND t.due_date IS NOT NULL
                          AND t.due_date < CURDATE()
                         THEN 1 ELSE 0 END) AS overdue_tasks
         FROM projects p
         INNER JOIN project_members current_member
            ON current_member.project_id = p.id AND current_member.user_id = ?
         LEFT JOIN project_members pm_all ON pm_all.project_id = p.id
         LEFT JOIN tasks t ON t.project_id = p.id
         WHERE p.status <> 'completed'
           ${filter}
         GROUP BY p.id, p.name, p.description, p.status
         ORDER BY overdue_tasks DESC, incomplete_tasks DESC, p.name ASC
         LIMIT 20`,
        params
    );
    return { type: 'project_summary', rows };
}

function buildContext(question, intentResult, retrieval) {
    const rows = retrieval.rows || [];
    return `
CĂ¢u há»i cá»§a ngÆ°á»i dĂ¹ng:
${question}

Káº¿t quáº£ phĂ¢n tĂ­ch:
${JSON.stringify(intentResult, null, 2)}

Dá»¯ liá»‡u láº¥y tá»« MySQL:
${rows.length > 0 ? JSON.stringify(rows, null, 2) : 'KhĂ´ng cĂ³ dá»¯ liá»‡u phĂ¹ há»£p.'}

YĂªu cáº§u tráº£ lá»i:
- Tráº£ lá»i theo Ä‘Ăºng ngĂ´n ngá»¯ Ä‘Æ°á»£c yĂªu cáº§u á»Ÿ pháº§n "NgĂ´n ngá»¯ tráº£ lá»i".
- Chá»‰ dá»±a trĂªn dá»¯ liá»‡u MySQL á»Ÿ trĂªn.
- Náº¿u khĂ´ng cĂ³ dá»¯ liá»‡u phĂ¹ há»£p, hĂ£y nĂ³i rĂµ lĂ  chÆ°a tĂ¬m tháº¥y dá»¯ liá»‡u.
- KhĂ´ng bá»‹a tĂªn dá»± Ă¡n, task, deadline, thĂ nh viĂªn hoáº·c sá»‘ liá»‡u.
- Tráº£ lá»i ngáº¯n gá»n, dá»… hiá»ƒu.
`;
}

function answerLanguageInstruction(language) {
    if (language === 'english') return 'Answer in English.';
    if (language === 'chinese') return 'ç”¨ä¸­æ–‡å›ç­”ă€‚';
    return 'Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.';
}

function normalizeLanguage(language) {
    const value = String(language || '').toLowerCase().trim();
    if (value === 'english' || value === 'en') return 'english';
    if (value === 'chinese' || value === 'zh' || value === 'zhongwen') return 'chinese';
    return 'vietnamese';
}

async function generateAnswer(context) {
    return callGemini(context, { temperature: 0.3 });
}

router.use(requireAuth);

router.post('/ask', async (req, res) => {
    try {
        const question = req.body.question?.toString().trim();
        if (!question) {
            return res.status(400).json({
                success: false,
                message: 'Vui lĂ²ng nháº­p cĂ¢u há»i.'
            });
        }

        const language = normalizeLanguage(req.body.language);
        const intent = await parseIntent(question);
        const retrieval = await retrieveSqlContext(intent, req.user.id);
        const context = `${buildContext(question, intent, retrieval)}

NgĂ´n ngá»¯ tráº£ lá»i:
${answerLanguageInstruction(language)}
`;
        const answer = await generateAnswer(context);

        return res.json({
            success: true,
            data: {
                answer,
                language,
                intent,
                retrieval_type: intent.retrieval_type || 'sql',
                rows: retrieval.rows || []
            }
        });
    } catch (err) {
        console.error('Lá»—i chatbot:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ xá»­ lĂ½ cĂ¢u há»i chatbot.',
            error: err.message
        });
    }
});

module.exports = router;

