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
const GEMINI_MODEL = process.env.GEMINI_MODEL || '';
let cachedGeminiModel = null;

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
                message: 'Bạn chưa đăng nhập.'
            });
        }

        req.user = jwt.verify(token, JWT_SECRET);
        next();
    } catch (err) {
        return res.status(401).json({
            success: false,
            message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.'
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

    const model = await resolveGeminiModel(apiKey);
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
    if (!response.ok) {
        const message = data.error?.message || 'Không thể gọi Gemini API.';
        throw new Error(message);
    }

    return data.candidates?.[0]?.content?.parts?.map((part) => part.text).join('\n').trim() || '';
}

async function resolveGeminiModel(apiKey) {
    if (GEMINI_MODEL) {
        const model = GEMINI_MODEL.startsWith('models/')
            ? GEMINI_MODEL
            : `models/${GEMINI_MODEL}`;
        return model;
    }

    if (cachedGeminiModel) return cachedGeminiModel;

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
        return methods.includes('generateContent');
    });

    const preferred = generativeModels.find((model) =>
        model.name.includes('flash') &&
        !model.name.includes('image') &&
        !model.name.includes('embedding')
    ) || generativeModels[0];

    if (!preferred?.name) {
        throw new Error('Không tìm thấy Gemini model nào hỗ trợ generateContent cho API key này.');
    }

    cachedGeminiModel = preferred.name;
    console.log(`Gemini model đang dùng: ${cachedGeminiModel}`);
    return cachedGeminiModel;
}

function fallbackIntent(question) {
    const q = question.toLowerCase();
    if (q.includes('quá hạn') || q.includes('trễ hạn')) {
        return { intent: 'find_overdue_tasks', retrieval_type: 'sql', entities: {} };
    }
    if (q.includes('task') || q.includes('nhiệm vụ')) {
        if (q.includes('của tôi') || q.includes('tôi')) {
            return { intent: 'list_my_tasks', retrieval_type: 'sql', entities: {} };
        }
        return { intent: 'project_summary', retrieval_type: 'sql', entities: {} };
    }
    if (q.includes('thành viên') || q.includes('ai tham gia')) {
        return { intent: 'project_members', retrieval_type: 'sql', entities: {} };
    }
    return { intent: 'general_help', retrieval_type: 'none', entities: {} };
}

async function parseIntent(question) {
    const prompt = `
Bạn là bộ phân tích câu hỏi cho ứng dụng quản lý dự án.
Hãy trả về JSON duy nhất, không markdown.

Các intent hợp lệ:
- list_my_tasks: user hỏi các task/nhiệm vụ của bản thân
- find_overdue_tasks: user hỏi task quá hạn/trễ hạn
- count_incomplete_tasks: user hỏi số task chưa hoàn thành
- project_summary: user hỏi tóm tắt/tình hình dự án
- project_members: user hỏi thành viên dự án
- general_help: câu hỏi chung, chưa cần truy vấn database

Schema JSON:
{
  "intent": "intent_name",
  "retrieval_type": "sql|none",
  "entities": {
    "project_name": "tên dự án nếu có"
  }
}

Câu hỏi: ${question}
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
        console.warn('Không thể phân tích intent bằng Gemini, dùng fallback:', err.message);
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
            summary: 'Người dùng hỏi câu hỏi chung về quản lý dự án.'
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
                    COALESCE(u.name, 'Cả team') AS assignee_name
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
                    COALESCE(pr.name, 'Thành viên') AS role_name
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
Câu hỏi của người dùng:
${question}

Kết quả phân tích:
${JSON.stringify(intentResult, null, 2)}

Dữ liệu lấy từ MySQL:
${rows.length > 0 ? JSON.stringify(rows, null, 2) : 'Không có dữ liệu phù hợp.'}

Yêu cầu trả lời:
- Trả lời theo đúng ngôn ngữ được yêu cầu ở phần "Ngôn ngữ trả lời".
- Chỉ dựa trên dữ liệu MySQL ở trên.
- Nếu không có dữ liệu phù hợp, hãy nói rõ là chưa tìm thấy dữ liệu.
- Không bịa tên dự án, task, deadline, thành viên hoặc số liệu.
- Trả lời ngắn gọn, dễ hiểu.
`;
}

function answerLanguageInstruction(language) {
    if (language === 'english') return 'Answer in English.';
    if (language === 'chinese') return '用中文回答。';
    return 'Trả lời bằng tiếng Việt.';
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
                message: 'Vui lòng nhập câu hỏi.'
            });
        }

        const language = normalizeLanguage(req.body.language);
        const intent = await parseIntent(question);
        const retrieval = await retrieveSqlContext(intent, req.user.id);
        const context = `${buildContext(question, intent, retrieval)}

Ngôn ngữ trả lời:
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
        console.error('Lỗi chatbot:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xử lý câu hỏi chatbot.',
            error: err.message
        });
    }
});

module.exports = router;
