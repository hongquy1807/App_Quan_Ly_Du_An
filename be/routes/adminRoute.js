const express = require('express');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

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
const ADMIN_ROLE_ID = Number(process.env.ADMIN_SYSTEM_ROLE_ID || 1);
const DEFAULT_MEMBER_ROLE_ID = 3;
const ALLOWED_FEEDBACK_STATUSES = new Set(['pending', 'reviewing', 'resolved', 'rejected']);
const ALLOWED_PROJECT_STATUSES = new Set(['planning', 'in_progress', 'completed', 'paused']);
const ALLOWED_USER_STATUSES = new Set(['active', 'suspended']);
const SORT_COLUMNS = {
    users: new Set(['id', 'name', 'email', 'created_at', 'last_login_at']),
    projects: new Set(['id', 'name', 'status', 'created_at', 'updated_at']),
    feedbacks: new Set(['id', 'title', 'status', 'created_at', 'updated_at'])
};

let usersStatusColumnPromise;

function sendError(res, status, message, errors) {
    return res.status(status).json({
        success: false,
        message,
        ...(errors ? { errors } : {})
    });
}

function getBearerToken(req) {
    const header = req.headers.authorization || '';
    if (!header.startsWith('Bearer ')) return null;
    return header.slice(7).trim();
}

function requireAuth(req, res, next) {
    try {
        const token = getBearerToken(req);
        if (!token) return sendError(res, 401, 'Bạn chưa đăng nhập.');
        req.user = jwt.verify(token, JWT_SECRET);
        return next();
    } catch (_) {
        return sendError(res, 401, 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.');
    }
}

async function requireAdmin(req, res, next) {
    try {
        const [rows] = await pool.query(
            `SELECT u.id, u.email, u.name, u.system_role_id, r.name AS role_name
             FROM users u
             LEFT JOIN roles r ON r.id = u.system_role_id
             WHERE u.id = ?
             LIMIT 1`,
            [req.user.id]
        );

        const user = rows[0];
        const roleName = String(user?.role_name || '').trim().toLowerCase();
        const isAdmin = user && (
            Number(user.system_role_id) === ADMIN_ROLE_ID ||
            ['admin', 'administrator', 'quản trị viên', 'quan tri vien'].includes(roleName)
        );

        if (!isAdmin) return sendError(res, 403, 'Bạn không có quyền truy cập khu vực Admin.');
        req.admin = user;
        return next();
    } catch (err) {
        console.error('Lỗi kiểm tra quyền Admin:', err);
        return sendError(res, 500, 'Không thể kiểm tra quyền Admin.');
    }
}

async function hasUsersStatusColumn() {
    if (!usersStatusColumnPromise) {
        usersStatusColumnPromise = pool.query(
            `SELECT COUNT(*) AS total
             FROM information_schema.columns
             WHERE table_schema = DATABASE()
               AND table_name = 'users'
               AND column_name = 'status'`
        ).then(([rows]) => Number(rows[0]?.total || 0) > 0).catch(() => false);
    }
    return usersStatusColumnPromise;
}

function normalizeEmail(value) {
    return String(value || '').trim().toLowerCase();
}

function normalizeText(value) {
    return String(value ?? '').trim();
}

function normalizeDate(value) {
    if (value === null || value === undefined || value === '') return null;
    const text = String(value).trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
    const date = new Date(text);
    if (Number.isNaN(date.getTime())) return null;
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function normalizeProjectStatus(value) {
    const aliases = {
        'Lên kế hoạch': 'planning',
        'Đang thực hiện': 'in_progress',
        'Đang làm': 'in_progress',
        'Hoàn thành': 'completed',
        'Tạm dừng': 'paused'
    };
    const normalized = aliases[String(value || '').trim()] || String(value || '').trim();
    return ALLOWED_PROJECT_STATUSES.has(normalized) ? normalized : null;
}

function normalizeUserStatus(value) {
    const aliases = {
        'Hoạt động': 'active',
        'Tạm khóa': 'suspended'
    };
    const normalized = aliases[String(value || '').trim()] || String(value || '').trim();
    return ALLOWED_USER_STATUSES.has(normalized) ? normalized : null;
}

function formatDate(value) {
    if (!value) return null;
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toISOString();
}

function mapUser(row) {
    return {
        id: Number(row.id),
        name: row.name || '',
        email: row.email,
        avatar: row.avatar || null,
        birthday: row.birthday || null,
        address: row.address || null,
        phone: row.phone || null,
        role: row.role_id ? { id: Number(row.role_id), name: row.role_name || '' } : null,
        role_id: row.role_id ? Number(row.role_id) : null,
        role_name: row.role_name || null,
        status: row.account_status || 'active',
        created_at: formatDate(row.created_at),
        last_login_at: formatDate(row.last_login_at)
    };
}

function mapProject(row) {
    return {
        id: Number(row.id),
        name: row.name,
        description: row.description || '',
        status: row.status || 'planning',
        owner: row.owner_id ? {
            id: Number(row.owner_id),
            name: row.owner_name || '',
            email: row.owner_email || null
        } : null,
        owner_id: row.owner_id ? Number(row.owner_id) : null,
        members_count: Number(row.members_count || 0),
        tasks_count: Number(row.tasks_count || 0),
        completed_tasks_count: Number(row.completed_tasks_count || 0),
        start_date: row.start_date || null,
        end_date: row.end_date || null,
        completed_at: formatDate(row.completed_at),
        completed_by: row.completed_by ? Number(row.completed_by) : null,
        completed_by_name: row.completed_by_name || null,
        created_at: formatDate(row.created_at),
        updated_at: formatDate(row.updated_at)
    };
}

function mapFeedback(row, attachments = []) {
    return {
        id: Number(row.id),
        user_id: row.user_id ? Number(row.user_id) : null,
        title: row.title,
        content: row.content || '',
        content_preview: row.content_preview || (row.content || '').slice(0, 160),
        sender: row.user_id ? {
            id: Number(row.user_id),
            name: row.user_name || 'Tài khoản đã xóa',
            email: row.user_email || null
        } : null,
        status: row.status,
        attachment_count: Number(row.attachment_count || attachments.length || 0),
        attachments,
        created_at: formatDate(row.created_at),
        updated_at: formatDate(row.updated_at)
    };
}

function mapAttachment(row) {
    return {
        id: Number(row.id),
        feedback_id: Number(row.feedback_id),
        file_name: row.file_name,
        file_url: row.file_url,
        file_type: row.file_type,
        mime_type: row.mime_type || null,
        file_size: row.file_size === null ? null : Number(row.file_size),
        created_at: formatDate(row.created_at)
    };
}

function parsePagination(query) {
    const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 20));
    return { page, limit, offset: (page - 1) * limit };
}

function paginationMeta(page, limit, total) {
    const totalPages = Math.max(1, Math.ceil(total / limit));
    return {
        page,
        limit,
        total,
        total_pages: totalPages,
        has_next: page < totalPages,
        has_previous: page > 1
    };
}

function parseSort(query, resource, fallback = 'created_at') {
    const sortBy = SORT_COLUMNS[resource].has(String(query.sort_by)) ? String(query.sort_by) : fallback;
    const sortOrder = String(query.sort_order).toLowerCase() === 'asc' ? 'ASC' : 'DESC';
    return { sortBy, sortOrder };
}

async function getUserById(userId) {
    const statusAvailable = await hasUsersStatusColumn();
    const statusSelect = statusAvailable ? 'u.status AS account_status' : "'active' AS account_status";
    const [rows] = await pool.query(
        `SELECT u.id, u.email, u.name, u.avatar, u.birthday, u.address, u.phone,
                u.created_at, u.last_login_at, u.system_role_id AS role_id,
                r.name AS role_name, ${statusSelect}
         FROM users u
         LEFT JOIN roles r ON r.id = u.system_role_id
         WHERE u.id = ?
         LIMIT 1`,
        [userId]
    );
    return rows[0] ? mapUser(rows[0]) : null;
}

async function assertRoleExists(roleId) {
    if (!Number.isInteger(roleId) || roleId < 1) return null;
    const [rows] = await pool.query('SELECT id, name FROM roles WHERE id = ? LIMIT 1', [roleId]);
    return rows[0] || null;
}

async function assertUserExists(userId) {
    const [rows] = await pool.query('SELECT id, email, name FROM users WHERE id = ? LIMIT 1', [userId]);
    return rows[0] || null;
}

async function assertNotLastAdmin(userId, changes = {}) {
    const current = await getUserById(userId);
    if (!current || Number(current.role_id) !== ADMIN_ROLE_ID) return;
    const wouldLoseAdmin = changes.role_id !== undefined && Number(changes.role_id) !== ADMIN_ROLE_ID;
    const wouldSuspend = changes.status !== undefined && changes.status === 'suspended';
    if (!wouldLoseAdmin && !wouldSuspend) return;

    const statusAvailable = await hasUsersStatusColumn();
    const activeCondition = statusAvailable ? "AND (status IS NULL OR status <> 'suspended')" : '';
    const [[countRow]] = await pool.query(
        `SELECT COUNT(*) AS total FROM users WHERE system_role_id = ? ${activeCondition}`,
        [ADMIN_ROLE_ID]
    );
    if (Number(countRow.total || 0) <= 1) {
        const error = new Error('Không thể hạ quyền hoặc khóa Admin cuối cùng.');
        error.statusCode = 422;
        throw error;
    }
}

async function getProjectDetail(projectId) {
    const [projectRows] = await pool.query(
        `SELECT p.id, p.name, p.description, p.status, p.owner_id,
                owner.name AS owner_name, owner.email AS owner_email,
                p.start_date, p.end_date, p.completed_at, p.completed_by,
                completed_user.name AS completed_by_name,
                p.created_at, p.updated_at,
                COUNT(DISTINCT pm.user_id) AS members_count,
                COUNT(DISTINCT t.id) AS tasks_count,
                COUNT(DISTINCT CASE WHEN t.status = 'done' THEN t.id END) AS completed_tasks_count
         FROM projects p
         LEFT JOIN users owner ON owner.id = p.owner_id
         LEFT JOIN users completed_user ON completed_user.id = p.completed_by
         LEFT JOIN project_members pm ON pm.project_id = p.id
         LEFT JOIN tasks t ON t.project_id = p.id
         WHERE p.id = ?
         GROUP BY p.id, p.name, p.description, p.status, p.owner_id,
                  owner.name, owner.email, p.start_date, p.end_date,
                  p.completed_at, p.completed_by, completed_user.name,
                  p.created_at, p.updated_at
         LIMIT 1`,
        [projectId]
    );
    if (!projectRows[0]) return null;

    const [memberRows, taskRows] = await Promise.all([
        pool.query(
            `SELECT pm.user_id, u.name, u.email, u.avatar,
                    pm.project_role_id, pr.name AS role_name, pm.joined_at
             FROM project_members pm
             INNER JOIN users u ON u.id = pm.user_id
             LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
             WHERE pm.project_id = ?
             ORDER BY CASE WHEN pm.project_role_id = 1 THEN 0 ELSE 1 END, u.name ASC`,
            [projectId]
        ),
        pool.query(
            `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                    assignee.name AS assignee_name, assignee.email AS assignee_email,
                    t.start_date, t.due_date, t.status, t.created_at, t.updated_at
             FROM tasks t
             LEFT JOIN users assignee ON assignee.id = t.assignee_id
             WHERE t.project_id = ?
             ORDER BY t.created_at DESC`,
            [projectId]
        )
    ]);

    const project = mapProject(projectRows[0]);
    const members = memberRows[0].map((row) => ({
        user_id: Number(row.user_id),
        name: row.name || '',
        email: row.email,
        avatar: row.avatar || null,
        project_role_id: row.project_role_id ? Number(row.project_role_id) : null,
        role_name: row.role_name || null,
        joined_at: formatDate(row.joined_at)
    }));
    const tasks = taskRows[0].map((row) => ({
        id: Number(row.id),
        project_id: Number(row.project_id),
        title: row.title,
        description: row.description || '',
        assignee_id: row.assignee_id ? Number(row.assignee_id) : null,
        assignee_name: row.assignee_name || null,
        assignee_email: row.assignee_email || null,
        start_date: row.start_date || null,
        due_date: row.due_date || null,
        status: row.status || 'todo',
        created_at: formatDate(row.created_at),
        updated_at: formatDate(row.updated_at)
    }));

    const taskSummary = tasks.reduce((summary, task) => {
        const status = ['todo', 'in_progress', 'review', 'done'].includes(task.status) ? task.status : 'todo';
        summary[status] += 1;
        summary.total += 1;
        return summary;
    }, { total: 0, todo: 0, in_progress: 0, review: 0, done: 0 });

    return { project, members, task_summary: taskSummary, tasks };
}

async function getFeedbackDetail(feedbackId) {
    const [feedbackRows] = await pool.query(
        `SELECT f.id, f.user_id, u.name AS user_name, u.email AS user_email,
                f.title, f.content, f.status, f.created_at, f.updated_at
         FROM feedbacks f
         LEFT JOIN users u ON u.id = f.user_id
         WHERE f.id = ?
         LIMIT 1`,
        [feedbackId]
    );
    if (!feedbackRows[0]) return null;
    const [attachmentRows] = await pool.query(
        `SELECT id, feedback_id, file_name, file_url, file_type,
                mime_type, file_size, created_at
         FROM feedback_attachments
         WHERE feedback_id = ?
         ORDER BY created_at ASC`,
        [feedbackId]
    );
    return mapFeedback(feedbackRows[0], attachmentRows.map(mapAttachment));
}

router.use(requireAuth, requireAdmin);

// GET /api/admin/overview
router.get('/overview', async (req, res) => {
    try {
        const limit = Math.min(20, Math.max(1, Number.parseInt(req.query.activity_limit, 10) || 5));
        const statusAvailable = await hasUsersStatusColumn();
        const activeUsersSql = statusAvailable
            ? "SELECT COUNT(*) AS total FROM users WHERE status IS NULL OR status = 'active'"
            : 'SELECT COUNT(*) AS total FROM users';
        const [countResults, activityResults] = await Promise.all([
            Promise.all([
                pool.query('SELECT COUNT(*) AS total FROM projects'),
                pool.query('SELECT COUNT(*) AS total FROM users'),
                pool.query('SELECT COUNT(*) AS total FROM feedbacks'),
                pool.query(activeUsersSql),
                pool.query("SELECT COUNT(*) AS total FROM projects WHERE COALESCE(status, 'planning') = 'in_progress'"),
                pool.query("SELECT COUNT(*) AS total FROM feedbacks WHERE status = 'pending'")
            ]),
            Promise.all([
                pool.query(
                    `SELECT 'project_created' AS type, p.id AS entity_id,
                            p.name AS title, CONCAT('Dự án ', p.name, ' đã được tạo.') AS description,
                            p.created_at
                     FROM projects p ORDER BY p.created_at DESC LIMIT ?`,
                    [limit]
                ),
                pool.query(
                    `SELECT 'user_created' AS type, u.id AS entity_id,
                            COALESCE(u.name, u.email) AS title, CONCAT(COALESCE(u.name, u.email), ' đã tham gia hệ thống.') AS description,
                            u.created_at
                     FROM users u ORDER BY u.created_at DESC LIMIT ?`,
                    [limit]
                ),
                pool.query(
                    `SELECT 'feedback_created' AS type, f.id AS entity_id,
                            f.title, CONCAT('Góp ý từ ', COALESCE(u.name, u.email, 'người dùng'), '.') AS description,
                            f.created_at
                     FROM feedbacks f LEFT JOIN users u ON u.id = f.user_id
                     ORDER BY f.created_at DESC LIMIT ?`,
                    [limit]
                )
            ])
        ]);

        const value = (index) => Number(countResults[index][0][0]?.total || 0);
        const activity = activityResults.flatMap(([rows]) => rows).sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, limit).map((row) => ({
            type: row.type,
            entity_id: Number(row.entity_id),
            title: row.title,
            description: row.description,
            created_at: formatDate(row.created_at)
        }));

        return res.json({
            success: true,
            data: {
                stats: {
                    total_projects: value(0),
                    total_users: value(1),
                    total_feedbacks: value(2),
                    active_users: value(3),
                    in_progress_projects: value(4),
                    pending_feedbacks: value(5)
                },
                activity,
                system: { status: 'operational', health_percent: 98 }
            }
        });
    } catch (err) {
        console.error('Lỗi lấy overview Admin:', err);
        return sendError(res, 500, 'Không thể lấy tổng quan Admin.');
    }
});

// GET /api/admin/users
router.get('/users', async (req, res) => {
    try {
        const { page, limit, offset } = parsePagination(req.query);
        const q = normalizeText(req.query.q).toLowerCase();
        const roleId = req.query.role_id ? Number(req.query.role_id) : null;
        const status = req.query.status ? normalizeUserStatus(req.query.status) : null;
        if (req.query.status && !status) return sendError(res, 400, 'Trạng thái người dùng không hợp lệ.');
        const { sortBy, sortOrder } = parseSort(req.query, 'users');
        const statusAvailable = await hasUsersStatusColumn();
        const statusSelect = statusAvailable ? 'u.status AS account_status' : "'active' AS account_status";
        const conditions = [];
        const params = [];
        if (q) {
            conditions.push('(LOWER(u.name) LIKE ? OR LOWER(u.email) LIKE ?)');
            params.push(`%${q}%`, `%${q}%`);
        }
        if (roleId) {
            conditions.push('u.system_role_id = ?');
            params.push(roleId);
        }
        if (status && statusAvailable) {
            conditions.push('u.status = ?');
            params.push(status);
        }
        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
        const [rows, countRows] = await Promise.all([
            pool.query(
                `SELECT u.id, u.email, u.name, u.avatar, u.birthday, u.address, u.phone,
                        u.created_at, u.last_login_at, u.system_role_id AS role_id,
                        r.name AS role_name, ${statusSelect}
                 FROM users u LEFT JOIN roles r ON r.id = u.system_role_id
                 ${where} ORDER BY u.${sortBy} ${sortOrder} LIMIT ? OFFSET ?`,
                [...params, limit, offset]
            ),
            pool.query(`SELECT COUNT(*) AS total FROM users u ${where}`, params)
        ]);
        const total = Number(countRows[0][0]?.total || 0);
        return res.json({ success: true, data: { items: rows[0].map(mapUser), pagination: paginationMeta(page, limit, total) } });
    } catch (err) {
        console.error('Lỗi lấy users Admin:', err);
        return sendError(res, 500, 'Không thể lấy danh sách người dùng.');
    }
});

// GET /api/admin/users/:id
router.get('/users/:id', async (req, res) => {
    try {
        const userId = Number(req.params.id);
        if (!userId) return sendError(res, 400, 'ID người dùng không hợp lệ.');
        const user = await getUserById(userId);
        if (!user) return sendError(res, 404, 'Không tìm thấy người dùng.');
        const [[owned], [memberships], [tasks], [feedbacks]] = await Promise.all([
            pool.query('SELECT COUNT(*) AS total FROM projects WHERE owner_id = ?', [userId]),
            pool.query('SELECT COUNT(*) AS total FROM project_members WHERE user_id = ?', [userId]),
            pool.query('SELECT COUNT(*) AS total FROM tasks WHERE assignee_id = ?', [userId]),
            pool.query('SELECT COUNT(*) AS total FROM feedbacks WHERE user_id = ?', [userId])
        ]);
        return res.json({
            success: true,
            data: {
                ...user,
                stats: {
                    owned_projects: Number(owned[0]?.total || 0),
                    project_memberships: Number(memberships[0]?.total || 0),
                    assigned_tasks: Number(tasks[0]?.total || 0),
                    feedbacks_sent: Number(feedbacks[0]?.total || 0)
                }
            }
        });
    } catch (err) {
        console.error('Lỗi lấy chi tiết user Admin:', err);
        return sendError(res, 500, 'Không thể lấy chi tiết người dùng.');
    }
});

// POST /api/admin/users
router.post('/users', async (req, res) => {
    try {
        const name = normalizeText(req.body.name);
        const email = normalizeEmail(req.body.email);
        const password = String(req.body.password || '');
        const rawRoleId = req.body.system_role_id ?? req.body.role_id ?? DEFAULT_MEMBER_ROLE_ID;
        const roleId = Number(rawRoleId);
        const status = normalizeUserStatus(req.body.status || 'active');
        const birthday = normalizeDate(req.body.birthday);
        if (!name) return sendError(res, 400, 'Họ tên không được để trống.', { name: 'Bắt buộc.' });
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return sendError(res, 400, 'Email không hợp lệ.', { email: 'Sai định dạng.' });
        if (password.length < 6) return sendError(res, 400, 'Mật khẩu phải có ít nhất 6 ký tự.', { password: 'Tối thiểu 6 ký tự.' });
        if (!Number.isInteger(roleId) || roleId < 1) return sendError(res, 400, 'Vai trò hệ thống không hợp lệ.');
        if (!status) return sendError(res, 400, 'Trạng thái người dùng không hợp lệ.');
        if (!birthday && req.body.birthday) return sendError(res, 400, 'Ngày sinh không hợp lệ.');
        if (!await assertRoleExists(roleId)) return sendError(res, 400, 'Vai trò hệ thống không tồn tại.');
        const statusAvailable = await hasUsersStatusColumn();
        if (req.body.status && !statusAvailable) return sendError(res, 409, 'CSDL chưa có cột users.status. Hãy chạy migration Admin trước.');
        const hash = await bcrypt.hash(password, 10);
        const columns = ['email', 'password', 'name', 'birthday', 'address', 'phone', 'system_role_id'];
        const values = [email, hash, name, birthday, normalizeText(req.body.address) || null, normalizeText(req.body.phone) || null, roleId];
        if (statusAvailable) {
            columns.push('status');
            values.push(status);
        }
        const placeholders = columns.map(() => '?').join(', ');
        const [result] = await pool.query(`INSERT INTO users (${columns.join(', ')}) VALUES (${placeholders})`, values);
        const user = await getUserById(result.insertId);
        return res.status(201).json({ success: true, message: 'Tạo người dùng thành công.', data: user });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') return sendError(res, 409, 'Email này đã tồn tại.');
        console.error('Lỗi tạo user Admin:', err);
        return sendError(res, 500, 'Không thể tạo người dùng.');
    }
});

// PATCH /api/admin/users/:id
router.patch('/users/:id', async (req, res) => {
    try {
        const userId = Number(req.params.id);
        if (!userId) return sendError(res, 400, 'ID người dùng không hợp lệ.');
        if (!await assertUserExists(userId)) return sendError(res, 404, 'Không tìm thấy người dùng.');
        const updates = {};
        if (req.body.name !== undefined) {
            const name = normalizeText(req.body.name);
            if (!name) return sendError(res, 400, 'Họ tên không được để trống.');
            updates.name = name;
        }
        if (req.body.email !== undefined) {
            const email = normalizeEmail(req.body.email);
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return sendError(res, 400, 'Email không hợp lệ.');
            updates.email = email;
        }
        if (req.body.system_role_id !== undefined || req.body.role_id !== undefined) {
            const rawRoleId = req.body.system_role_id ?? req.body.role_id;
            const roleId = Number(rawRoleId);
            if (!Number.isInteger(roleId) || roleId < 1) return sendError(res, 400, 'Vai trò hệ thống không hợp lệ.');
            if (!await assertRoleExists(roleId)) return sendError(res, 400, 'Vai trò hệ thống không tồn tại.');
            updates.system_role_id = roleId;
            updates.role_id = roleId;
        }
        if (req.body.status !== undefined) {
            const status = normalizeUserStatus(req.body.status);
            if (!status) return sendError(res, 400, 'Trạng thái người dùng không hợp lệ.');
            if (!await hasUsersStatusColumn()) return sendError(res, 409, 'CSDL chưa có cột users.status. Hãy chạy migration Admin trước.');
            updates.status = status;
        }
        for (const field of ['address', 'phone', 'avatar']) {
            if (req.body[field] !== undefined) updates[field] = normalizeText(req.body[field]) || null;
        }
        if (req.body.birthday !== undefined) {
            updates.birthday = normalizeDate(req.body.birthday);
            if (!updates.birthday && req.body.birthday) return sendError(res, 400, 'Ngày sinh không hợp lệ.');
        }
        if (!Object.keys(updates).length) return sendError(res, 400, 'Không có dữ liệu cần cập nhật.');
        await assertNotLastAdmin(userId, { role_id: updates.role_id, status: updates.status });
        const setParts = [];
        const params = [];
        for (const [field, value] of Object.entries(updates)) {
            if (!['name', 'email', 'system_role_id', 'status', 'address', 'phone', 'avatar', 'birthday'].includes(field)) continue;
            setParts.push(`\`${field}\` = ?`);
            params.push(value);
        }
        params.push(userId);
        await pool.query(`UPDATE users SET ${setParts.join(', ')} WHERE id = ?`, params);
        return res.json({ success: true, message: 'Cập nhật người dùng thành công.', data: await getUserById(userId) });
    } catch (err) {
        if (err.statusCode) return sendError(res, err.statusCode, err.message);
        if (err.code === 'ER_DUP_ENTRY') return sendError(res, 409, 'Email này đã tồn tại.');
        console.error('Lỗi cập nhật user Admin:', err);
        return sendError(res, 500, 'Không thể cập nhật người dùng.');
    }
});

// PATCH /api/admin/users/:id/password
router.patch('/users/:id/password', async (req, res) => {
    try {
        const userId = Number(req.params.id);
        const password = String(req.body.new_password || req.body.password || '');
        if (!userId) return sendError(res, 400, 'ID người dùng không hợp lệ.');
        if (password.length < 6) return sendError(res, 400, 'Mật khẩu phải có ít nhất 6 ký tự.');
        if (!await assertUserExists(userId)) return sendError(res, 404, 'Không tìm thấy người dùng.');
        await pool.query('UPDATE users SET password = ? WHERE id = ?', [await bcrypt.hash(password, 10), userId]);
        return res.json({ success: true, message: 'Đổi mật khẩu thành công.' });
    } catch (err) {
        console.error('Lỗi đổi mật khẩu Admin:', err);
        return sendError(res, 500, 'Không thể đổi mật khẩu.');
    }
});

// DELETE /api/admin/users/:id?confirm=ID
router.delete('/users/:id', async (req, res) => {
    try {
        const userId = Number(req.params.id);
        if (!userId) return sendError(res, 400, 'ID người dùng không hợp lệ.');
        if (String(req.query.confirm) !== String(userId)) return sendError(res, 400, 'Cần xác nhận bằng query confirm=<id> trước khi xóa.');
        if (!await assertUserExists(userId)) return sendError(res, 404, 'Không tìm thấy người dùng.');
        await assertNotLastAdmin(userId, { role_id: 2, status: 'suspended' });
        const [[owned]] = await pool.query('SELECT COUNT(*) AS total FROM projects WHERE owner_id = ?', [userId]);
        if (Number(owned.total || 0) > 0) return sendError(res, 409, 'Không thể xóa người dùng đang là chủ dự án. Hãy chuyển chủ dự án hoặc khóa tài khoản.');
        await pool.query('DELETE FROM users WHERE id = ?', [userId]);
        return res.json({ success: true, message: 'Xóa người dùng thành công.' });
    } catch (err) {
        if (err.statusCode) return sendError(res, err.statusCode, err.message);
        console.error('Lỗi xóa user Admin:', err);
        return sendError(res, 500, 'Không thể xóa người dùng.');
    }
});

// GET /api/admin/projects
router.get('/projects', async (req, res) => {
    try {
        const { page, limit, offset } = parsePagination(req.query);
        const q = normalizeText(req.query.q).toLowerCase();
        const status = req.query.status ? normalizeProjectStatus(req.query.status) : null;
        if (req.query.status && !status) return sendError(res, 400, 'Trạng thái dự án không hợp lệ.');
        const ownerId = req.query.owner_id ? Number(req.query.owner_id) : null;
        const { sortBy, sortOrder } = parseSort(req.query, 'projects', 'updated_at');
        const conditions = [];
        const params = [];
        if (q) {
            conditions.push('(LOWER(p.name) LIKE ? OR LOWER(COALESCE(p.description, \'\')) LIKE ? OR LOWER(owner.name) LIKE ? OR LOWER(owner.email) LIKE ?)');
            params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
        }
        if (status) { conditions.push('COALESCE(p.status, \'planning\') = ?'); params.push(status); }
        if (ownerId) { conditions.push('p.owner_id = ?'); params.push(ownerId); }
        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
        const baseFrom = `FROM projects p
            LEFT JOIN users owner ON owner.id = p.owner_id
            LEFT JOIN users completed_user ON completed_user.id = p.completed_by
            LEFT JOIN project_members pm ON pm.project_id = p.id
            LEFT JOIN tasks t ON t.project_id = p.id`;
        const select = `SELECT p.id, p.name, p.description, p.status, p.owner_id,
                owner.name AS owner_name, owner.email AS owner_email,
                p.start_date, p.end_date, p.completed_at, p.completed_by,
                completed_user.name AS completed_by_name, p.created_at, p.updated_at,
                COUNT(DISTINCT pm.user_id) AS members_count,
                COUNT(DISTINCT t.id) AS tasks_count,
                COUNT(DISTINCT CASE WHEN t.status = 'done' THEN t.id END) AS completed_tasks_count`;
        const [rows, countRows] = await Promise.all([
            pool.query(`${select} ${baseFrom} ${where}
                GROUP BY p.id, p.name, p.description, p.status, p.owner_id, owner.name, owner.email,
                         p.start_date, p.end_date, p.completed_at, p.completed_by, completed_user.name,
                         p.created_at, p.updated_at
                ORDER BY p.${sortBy} ${sortOrder} LIMIT ? OFFSET ?`, [...params, limit, offset]),
            pool.query(`SELECT COUNT(DISTINCT p.id) AS total ${baseFrom} ${where}`, params)
        ]);
        const total = Number(countRows[0][0]?.total || 0);
        return res.json({ success: true, data: { items: rows[0].map(mapProject), pagination: paginationMeta(page, limit, total) } });
    } catch (err) {
        console.error('Lỗi lấy projects Admin:', err);
        return sendError(res, 500, 'Không thể lấy danh sách dự án.');
    }
});

// GET /api/admin/projects/:id
router.get('/projects/:id', async (req, res) => {
    try {
        const projectId = Number(req.params.id);
        if (!projectId) return sendError(res, 400, 'ID dự án không hợp lệ.');
        const data = await getProjectDetail(projectId);
        if (!data) return sendError(res, 404, 'Không tìm thấy dự án.');
        return res.json({ success: true, data });
    } catch (err) {
        console.error('Lỗi lấy chi tiết project Admin:', err);
        return sendError(res, 500, 'Không thể lấy chi tiết dự án.');
    }
});

function validateProjectBody(body) {
    const name = normalizeText(body.name);
    const status = normalizeProjectStatus(body.status || 'planning');
    const ownerId = Number(body.owner_id || body.ownerId || 0);
    const startDate = normalizeDate(body.start_date || body.startDate);
    const endDate = normalizeDate(body.end_date || body.endDate);
    if (!name) return { error: 'Tên dự án không được để trống.' };
    if (!status) return { error: 'Trạng thái dự án không hợp lệ.' };
    if (!ownerId) return { error: 'owner_id là bắt buộc.' };
    if ((body.start_date || body.startDate) && !startDate) return { error: 'Ngày bắt đầu không hợp lệ.' };
    if ((body.end_date || body.endDate) && !endDate) return { error: 'Ngày kết thúc không hợp lệ.' };
    if (startDate && endDate && startDate > endDate) return { error: 'Ngày kết thúc phải sau ngày bắt đầu.' };
    return { name, description: normalizeText(body.description) || null, ownerId, status, startDate, endDate };
}

function normalizeMemberIds(body) {
    const ids = Array.isArray(body.member_ids) ? body.member_ids : (Array.isArray(body.members) ? body.members.map((m) => m.user_id || m.id || m) : []);
    return [...new Set(ids.map(Number).filter(Boolean))];
}

async function validateMemberIds(connection, memberIds) {
    if (!memberIds.length) return;
    const placeholders = memberIds.map(() => '?').join(',');
    const [rows] = await connection.query(`SELECT id FROM users WHERE id IN (${placeholders})`, memberIds);
    if (rows.length !== memberIds.length) {
        const found = new Set(rows.map((row) => Number(row.id)));
        const missing = memberIds.filter((id) => !found.has(id));
        const error = new Error(`Người dùng không tồn tại: ${missing.join(', ')}.`);
        error.statusCode = 400;
        throw error;
    }
}

async function insertProjectMembers(connection, projectId, ownerId, memberIds) {
    const uniqueIds = [...new Set([ownerId, ...memberIds])];
    await validateMemberIds(connection, uniqueIds);
    const values = uniqueIds.map((userId) => [projectId, userId, userId === ownerId ? 1 : DEFAULT_MEMBER_ROLE_ID]);
    if (values.length) await connection.query('INSERT INTO project_members (project_id, user_id, project_role_id) VALUES ?', [values]);
}

// POST /api/admin/projects
router.post('/projects', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const payload = validateProjectBody(req.body);
        if (payload.error) return sendError(res, 400, payload.error);
        if (!await assertUserExists(payload.ownerId)) return sendError(res, 400, 'Trưởng dự án không tồn tại.');
        const memberIds = normalizeMemberIds(req.body);
        await connection.beginTransaction();
        const [result] = await connection.query(
            `INSERT INTO projects (name, description, owner_id, status, start_date, end_date, completed_at, completed_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [payload.name, payload.description, payload.ownerId, payload.status, payload.startDate, payload.endDate,
                payload.status === 'completed' ? new Date() : null, payload.status === 'completed' ? req.admin.id : null]
        );
        await insertProjectMembers(connection, result.insertId, payload.ownerId, memberIds);
        await connection.commit();
        return res.status(201).json({ success: true, message: 'Tạo dự án thành công.', data: await getProjectDetail(result.insertId) });
    } catch (err) {
        await connection.rollback();
        if (err.statusCode) return sendError(res, err.statusCode, err.message);
        console.error('Lỗi tạo project Admin:', err);
        return sendError(res, 500, 'Không thể tạo dự án.');
    } finally {
        connection.release();
    }
});

// PATCH /api/admin/projects/:id
router.patch('/projects/:id', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const projectId = Number(req.params.id);
        if (!projectId) return sendError(res, 400, 'ID dự án không hợp lệ.');
        const [existingRows] = await connection.query('SELECT id, owner_id, status, start_date, end_date FROM projects WHERE id = ? LIMIT 1', [projectId]);
        if (!existingRows[0]) return sendError(res, 404, 'Không tìm thấy dự án.');
        const existing = existingRows[0];
        const updates = {};
        for (const field of ['name', 'description']) {
            if (req.body[field] !== undefined) updates[field] = field === 'name' ? normalizeText(req.body[field]) : (normalizeText(req.body[field]) || null);
        }
        if (updates.name !== undefined && !updates.name) return sendError(res, 400, 'Tên dự án không được để trống.');
        if (req.body.owner_id !== undefined || req.body.ownerId !== undefined) {
            updates.owner_id = Number(req.body.owner_id || req.body.ownerId);
            if (!updates.owner_id || !await assertUserExists(updates.owner_id)) return sendError(res, 400, 'Trưởng dự án không tồn tại.');
        }
        if (req.body.status !== undefined) {
            updates.status = normalizeProjectStatus(req.body.status);
            if (!updates.status) return sendError(res, 400, 'Trạng thái dự án không hợp lệ.');
        }
        for (const [field, source] of [['start_date', 'start_date'], ['end_date', 'end_date']]) {
            if (req.body[source] !== undefined) {
                updates[field] = normalizeDate(req.body[source]);
                if (!updates[field] && req.body[source]) return sendError(res, 400, `${field} không hợp lệ.`);
            }
        }
        if (!Object.keys(updates).length) return sendError(res, 400, 'Không có dữ liệu cần cập nhật.');
        const nextStatus = updates.status || existing.status || 'planning';
        if ((updates.start_date || existing.start_date) && (updates.end_date || existing.end_date) && updates.start_date > updates.end_date) return sendError(res, 400, 'Ngày kết thúc phải sau ngày bắt đầu.');
        await connection.beginTransaction();
        const setParts = [];
        const params = [];
        for (const [field, value] of Object.entries(updates)) {
            setParts.push(`\`${field}\` = ?`);
            params.push(value);
        }
        if (nextStatus === 'completed' && existing.status !== 'completed') {
            setParts.push('completed_at = NOW()', 'completed_by = ?');
            params.push(req.admin.id);
        } else if (nextStatus !== 'completed' && existing.status === 'completed') {
            setParts.push('completed_at = NULL', 'completed_by = NULL');
        }
        params.push(projectId);
        await connection.query(`UPDATE projects SET ${setParts.join(', ')} WHERE id = ?`, params);
        if (updates.owner_id && updates.owner_id !== Number(existing.owner_id)) {
            await connection.query('INSERT INTO project_members (project_id, user_id, project_role_id) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE project_role_id = 1', [projectId, updates.owner_id]);
        }
        await connection.commit();
        return res.json({ success: true, message: 'Cập nhật dự án thành công.', data: await getProjectDetail(projectId) });
    } catch (err) {
        await connection.rollback();
        console.error('Lỗi cập nhật project Admin:', err);
        return sendError(res, 500, 'Không thể cập nhật dự án.');
    } finally {
        connection.release();
    }
});

// PUT /api/admin/projects/:id/members
router.put('/projects/:id/members', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const projectId = Number(req.params.id);
        const [projectRows] = await connection.query('SELECT id, owner_id FROM projects WHERE id = ? LIMIT 1', [projectId]);
        if (!projectRows[0]) return sendError(res, 404, 'Không tìm thấy dự án.');
        if (!Array.isArray(req.body.members)) return sendError(res, 400, 'members phải là một mảng.');
        const members = req.body.members.map((member) => ({
            userId: Number(member.user_id || member.id),
            roleId: Number(member.project_role_id || member.role_id || DEFAULT_MEMBER_ROLE_ID)
        })).filter((member) => member.userId);
        const ownerId = Number(projectRows[0].owner_id);
        if (!members.some((member) => member.userId === ownerId)) members.push({ userId: ownerId, roleId: 1 });
        if (members.some((member) => ![1, 2, 3].includes(member.roleId))) return sendError(res, 400, 'project_role_id không hợp lệ.');
        await connection.beginTransaction();
        await validateMemberIds(connection, members.map((member) => member.userId));
        await connection.query('DELETE FROM project_members WHERE project_id = ?', [projectId]);
        await connection.query('INSERT INTO project_members (project_id, user_id, project_role_id) VALUES ?', [members.map((member) => [projectId, member.userId, member.userId === ownerId ? 1 : member.roleId])]);
        await connection.commit();
        return res.json({ success: true, message: 'Cập nhật thành viên dự án thành công.', data: await getProjectDetail(projectId) });
    } catch (err) {
        await connection.rollback();
        if (err.statusCode) return sendError(res, err.statusCode, err.message);
        console.error('Lỗi cập nhật member project Admin:', err);
        return sendError(res, 500, 'Không thể cập nhật thành viên dự án.');
    } finally {
        connection.release();
    }
});

// DELETE /api/admin/projects/:id?confirm=ID
router.delete('/projects/:id', async (req, res) => {
    try {
        const projectId = Number(req.params.id);
        if (!projectId) return sendError(res, 400, 'ID dự án không hợp lệ.');
        if (String(req.query.confirm) !== String(projectId)) return sendError(res, 400, 'Cần xác nhận bằng query confirm=<id> trước khi xóa.');
        const [result] = await pool.query('DELETE FROM projects WHERE id = ?', [projectId]);
        if (!result.affectedRows) return sendError(res, 404, 'Không tìm thấy dự án.');
        return res.json({ success: true, message: 'Xóa dự án thành công.' });
    } catch (err) {
        console.error('Lỗi xóa project Admin:', err);
        return sendError(res, 500, 'Không thể xóa dự án.');
    }
});

// GET /api/admin/feedbacks
router.get('/feedbacks', async (req, res) => {
    try {
        const { page, limit, offset } = parsePagination(req.query);
        const q = normalizeText(req.query.q).toLowerCase();
        const status = req.query.status ? String(req.query.status).trim() : null;
        if (status && !ALLOWED_FEEDBACK_STATUSES.has(status)) return sendError(res, 400, 'Trạng thái góp ý không hợp lệ.');
        const { sortBy, sortOrder } = parseSort(req.query, 'feedbacks');
        const conditions = [];
        const params = [];
        if (q) {
            conditions.push('(LOWER(f.title) LIKE ? OR LOWER(f.content) LIKE ? OR LOWER(COALESCE(u.name, \'\')) LIKE ? OR LOWER(COALESCE(u.email, \'\')) LIKE ?)');
            params.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
        }
        if (status) { conditions.push('f.status = ?'); params.push(status); }
        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
        const from = `FROM feedbacks f LEFT JOIN users u ON u.id = f.user_id LEFT JOIN feedback_attachments fa ON fa.feedback_id = f.id`;
        const [rows, countRows, statusRows] = await Promise.all([
            pool.query(
                `SELECT f.id, f.user_id, u.name AS user_name, u.email AS user_email,
                        f.title, LEFT(f.content, 160) AS content_preview, f.status,
                        f.created_at, f.updated_at, COUNT(fa.id) AS attachment_count
                 ${from} ${where}
                 GROUP BY f.id, f.user_id, u.name, u.email, f.title, f.content, f.status, f.created_at, f.updated_at
                 ORDER BY f.${sortBy} ${sortOrder} LIMIT ? OFFSET ?`,
                [...params, limit, offset]
            ),
            pool.query(`SELECT COUNT(DISTINCT f.id) AS total ${from} ${where}`, params),
            pool.query('SELECT status, COUNT(*) AS total FROM feedbacks GROUP BY status')
        ]);
        const statusCounts = { pending: 0, reviewing: 0, resolved: 0, rejected: 0 };
        statusRows[0].forEach((row) => { if (Object.prototype.hasOwnProperty.call(statusCounts, row.status)) statusCounts[row.status] = Number(row.total || 0); });
        const total = Number(countRows[0][0]?.total || 0);
        return res.json({ success: true, data: { items: rows[0].map(mapFeedback), pagination: paginationMeta(page, limit, total), status_counts: statusCounts } });
    } catch (err) {
        console.error('Lỗi lấy feedbacks Admin:', err);
        return sendError(res, 500, 'Không thể lấy danh sách thư góp ý.');
    }
});

// GET /api/admin/feedbacks/:id
router.get('/feedbacks/:id', async (req, res) => {
    try {
        const feedbackId = Number(req.params.id);
        if (!feedbackId) return sendError(res, 400, 'ID góp ý không hợp lệ.');
        const feedback = await getFeedbackDetail(feedbackId);
        if (!feedback) return sendError(res, 404, 'Không tìm thấy góp ý.');
        return res.json({ success: true, data: feedback });
    } catch (err) {
        console.error('Lỗi lấy feedback detail Admin:', err);
        return sendError(res, 500, 'Không thể lấy chi tiết góp ý.');
    }
});

// PATCH /api/admin/feedbacks/:id/status
router.patch('/feedbacks/:id/status', async (req, res) => {
    try {
        const feedbackId = Number(req.params.id);
        const status = String(req.body.status || '').trim();
        if (!feedbackId) return sendError(res, 400, 'ID góp ý không hợp lệ.');
        if (!ALLOWED_FEEDBACK_STATUSES.has(status)) return sendError(res, 400, 'Trạng thái góp ý không hợp lệ.');
        const [result] = await pool.query('UPDATE feedbacks SET status = ? WHERE id = ?', [status, feedbackId]);
        if (!result.affectedRows) return sendError(res, 404, 'Không tìm thấy góp ý.');
        return res.json({ success: true, message: 'Cập nhật trạng thái góp ý thành công.', data: await getFeedbackDetail(feedbackId) });
    } catch (err) {
        console.error('Lỗi cập nhật feedback Admin:', err);
        return sendError(res, 500, 'Không thể cập nhật trạng thái góp ý.');
    }
});

// DELETE /api/admin/feedbacks/:id
router.delete('/feedbacks/:id', async (req, res) => {
    try {
        const feedbackId = Number(req.params.id);
        if (!feedbackId) return sendError(res, 400, 'ID góp ý không hợp lệ.');
        const [result] = await pool.query('DELETE FROM feedbacks WHERE id = ?', [feedbackId]);
        if (!result.affectedRows) return sendError(res, 404, 'Không tìm thấy góp ý.');
        return res.json({ success: true, message: 'Xóa góp ý thành công.' });
    } catch (err) {
        console.error('Lỗi xóa feedback Admin:', err);
        return sendError(res, 500, 'Không thể xóa thư góp ý.');
    }
});

// GET /api/admin/catalogs
router.get('/catalogs', async (_req, res) => {
    try {
        const [systemRoles, projectRoles] = await Promise.all([
            pool.query('SELECT id, name FROM roles ORDER BY id ASC'),
            pool.query('SELECT id, name FROM project_roles ORDER BY id ASC')
        ]);
        return res.json({
            success: true,
            data: {
                system_roles: systemRoles[0].map((row) => ({ id: Number(row.id), name: row.name })),
                project_roles: projectRoles[0].map((row) => ({ id: Number(row.id), name: row.name })),
                user_statuses: [{ value: 'active', label: 'Hoạt động' }, { value: 'suspended', label: 'Tạm khóa' }],
                project_statuses: [
                    { value: 'planning', label: 'Lên kế hoạch' },
                    { value: 'in_progress', label: 'Đang thực hiện' },
                    { value: 'completed', label: 'Hoàn thành' },
                    { value: 'paused', label: 'Tạm dừng' }
                ],
                feedback_statuses: [
                    { value: 'pending', label: 'Chờ xử lý' },
                    { value: 'reviewing', label: 'Đang xem xét' },
                    { value: 'resolved', label: 'Đã xử lý' },
                    { value: 'rejected', label: 'Từ chối' }
                ]
            }
        });
    } catch (err) {
        console.error('Lỗi lấy catalog Admin:', err);
        return sendError(res, 500, 'Không thể lấy catalog Admin.');
    }
});

module.exports = router;
