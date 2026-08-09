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

const projectColors = [
    '#6366F1',
    '#EC4899',
    '#F59E0B',
    '#10B981',
    '#8B5CF6',
    '#EF4444',
    '#3B82F6'
];

function getProjectColor(projectId) {
    return projectColors[Math.abs(Number(projectId || 0)) % projectColors.length];
}

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

function formatDate(value) {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return null;

    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function normalizeDate(value, fallback = new Date()) {
    const parsed = formatDate(value);
    if (parsed) return parsed;
    return formatDate(fallback);
}

function addDays(dateText, days) {
    const date = new Date(`${dateText}T00:00:00`);
    date.setDate(date.getDate() + days);
    return formatDate(date);
}

function getStartOfWeek(value) {
    const baseText = normalizeDate(value, new Date());
    const date = new Date(`${baseText}T00:00:00`);
    const weekday = date.getDay() === 0 ? 7 : date.getDay();
    date.setDate(date.getDate() - weekday + 1);
    return formatDate(date);
}

async function tableExists(connection, tableName) {
    const [rows] = await connection.query('SHOW TABLES LIKE ?', [tableName]);
    return rows.length > 0;
}

async function columnExists(connection, tableName, columnName) {
    const [rows] = await connection.query(
        `SHOW COLUMNS FROM \`${tableName}\` LIKE ?`,
        [columnName]
    );
    return rows.length > 0;
}

function mapProject(row) {
    return {
        id: String(row.id),
        name: row.name,
        description: row.description,
        color: getProjectColor(row.id),
        status: row.status,
        start_date: row.start_date,
        end_date: row.end_date,
        project_role_id: row.project_role_id,
        role_name: row.role_name
    };
}

function statusProgress(status) {
    switch (status) {
        case 'done':
            return 100;
        case 'review':
            return 80;
        case 'in_progress':
            return 50;
        case 'todo':
        default:
            return 0;
    }
}

function mapTask(row) {
    const startDate = formatDate(row.start_date) || formatDate(row.created_at);
    const endDate = formatDate(row.end_date) || formatDate(row.due_date) || startDate;
    const subtaskTotal = Number(row.subtask_total || 0);
    const subtaskDone = Number(row.subtask_done || 0);
    const progress = subtaskTotal > 0
        ? Math.round((subtaskDone / subtaskTotal) * 100)
        : statusProgress(row.status);

    return {
        id: String(row.id),
        title: row.title,
        description: row.description,
        projectId: String(row.project_id),
        project_id: row.project_id,
        projectName: row.project_name,
        project_name: row.project_name,
        assignee_id: row.assignee_id,
        assignee_name: row.assignee_name,
        assignee_email: row.assignee_email,
        startDate,
        start_date: startDate,
        endDate,
        end_date: endDate,
        due_date: formatDate(row.due_date),
        status: row.status,
        color: getProjectColor(row.project_id),
        projectColor: getProjectColor(row.project_id),
        progress,
        subtask_total: subtaskTotal,
        subtask_done: subtaskDone,
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

async function getAccessibleProjects(userId) {
    const [rows] = await pool.query(
        `SELECT p.id, p.name, p.description, p.status, p.start_date, p.end_date,
                pm.project_role_id, pr.name AS role_name
         FROM projects p
         LEFT JOIN project_members pm
                ON pm.project_id = p.id AND pm.user_id = ?
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         WHERE p.owner_id = ? OR pm.user_id = ?
         ORDER BY p.updated_at DESC, p.created_at DESC`,
        [userId, userId, userId]
    );

    return rows.map(mapProject);
}

async function getTimelineTasks({
    userId,
    projectId,
    startDate,
    endDate
}) {
    const connection = await pool.getConnection();
    try {
        const hasSubtasks = await tableExists(connection, 'task_subtasks');
        const hasTaskStartDate = await columnExists(connection, 'tasks', 'start_date');
        const startDateSelect = hasTaskStartDate
            ? 't.start_date'
            : 'DATE(t.created_at) AS start_date';
        const taskStartExpression = hasTaskStartDate
            ? 'COALESCE(t.start_date, DATE(t.created_at))'
            : 'DATE(t.created_at)';
        const taskEndExpression = `COALESCE(t.due_date, ${taskStartExpression})`;
        const startDateGroupBy = hasTaskStartDate ? 't.start_date,' : '';
        const subtaskSelect = hasSubtasks
            ? `COUNT(ts.id) AS subtask_total,
               SUM(CASE WHEN ts.is_completed = 1 THEN 1 ELSE 0 END) AS subtask_done`
            : `0 AS subtask_total, 0 AS subtask_done`;
        const subtaskJoin = hasSubtasks
            ? 'LEFT JOIN task_subtasks ts ON ts.task_id = t.id'
            : '';

        const filters = [
            '(t.assignee_id = ? OR t.assignee_id IS NULL)',
            "t.status <> 'done'",
            `${taskEndExpression} >= ?`,
            `${taskStartExpression} <= ?`
        ];
        const values = [userId, startDate, endDate];

        if (projectId) {
            filters.push('t.project_id = ?');
            values.push(projectId);
        }

        const [rows] = await connection.query(
            `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                    ${startDateSelect}, t.due_date, t.status, t.created_at, t.updated_at,
                    p.name AS project_name,
                    assignee.name AS assignee_name,
                    assignee.email AS assignee_email,
                    ${subtaskSelect}
             FROM tasks t
             INNER JOIN projects p ON p.id = t.project_id
             LEFT JOIN users assignee ON assignee.id = t.assignee_id
             ${subtaskJoin}
             WHERE ${filters.join(' AND ')}
             GROUP BY t.id, t.project_id, t.title, t.description, t.assignee_id,
                      ${startDateGroupBy}
                      t.due_date, t.status, t.created_at, t.updated_at,
                      p.name, assignee.name, assignee.email
             ORDER BY DATE(t.created_at) ASC,
                      CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END,
                      t.due_date ASC,
                      t.updated_at DESC`,
            values
        );

        return rows.map(mapTask);
    } finally {
        connection.release();
    }
}

function buildStats(tasks) {
    return {
        total_tasks: tasks.length,
        completed_tasks: tasks.filter((task) => task.status === 'done').length,
        in_progress_tasks: tasks.filter((task) => task.status === 'in_progress').length,
        review_tasks: tasks.filter((task) => task.status === 'review').length,
        todo_tasks: tasks.filter((task) => task.status === 'todo').length,
        overdue_tasks: tasks.filter((task) => {
            if (!task.end_date || task.status === 'done') return false;
            return new Date(`${task.end_date}T00:00:00`) < new Date(`${formatDate(new Date())}T00:00:00`);
        }).length
    };
}

router.use(requireAuth);

// GET /api/timeline
// Data tổng hợp cho timeline_screen.dart: dropdown dự án, task trong tuần, thống kê.
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const weekStart = getStartOfWeek(req.query.week_start || req.query.start_date);
        const weekEnd = normalizeDate(req.query.week_end || req.query.end_date, new Date(`${addDays(weekStart, 6)}T00:00:00`));
        const projectId = req.query.project_id ? Number(req.query.project_id) : null;
        if (projectId !== null && !Number.isInteger(projectId)) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const [projects, tasks] = await Promise.all([
            getAccessibleProjects(userId),
            getTimelineTasks({
                userId,
                projectId,
                startDate: weekStart,
                endDate: weekEnd
            })
        ]);

        return res.json({
            success: true,
            data: {
                week: {
                    start_date: weekStart,
                    end_date: weekEnd
                },
                selected_project_id: projectId,
                current_user_id: userId,
                projects,
                tasks,
                stats: buildStats(tasks)
            }
        });
    } catch (err) {
        console.error('Lỗi lấy dữ liệu timeline:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy dữ liệu lịch.',
            error: err.message
        });
    }
});

// GET /api/timeline/projects
// Danh sách dự án cho dropdown lọc timeline.
router.get('/projects', async (req, res) => {
    try {
        const projects = await getAccessibleProjects(req.user.id);
        return res.json({
            success: true,
            data: projects
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách dự án timeline:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách dự án.',
            error: err.message
        });
    }
});

// GET /api/timeline/tasks
// Danh sách task được gán cho tài khoản đang đăng nhập theo khoảng ngày và project_id.
router.get('/tasks', async (req, res) => {
    try {
        const userId = req.user.id;
        const startDate = normalizeDate(req.query.start_date, new Date());
        const endDate = normalizeDate(req.query.end_date, new Date(`${addDays(startDate, 6)}T00:00:00`));
        const projectId = req.query.project_id ? Number(req.query.project_id) : null;
        if (projectId !== null && !Number.isInteger(projectId)) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const tasks = await getTimelineTasks({
            userId,
            projectId,
            startDate,
            endDate
        });

        return res.json({
            success: true,
            data: {
                start_date: startDate,
                end_date: endDate,
                current_user_id: userId,
                tasks,
                stats: buildStats(tasks)
            }
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách task timeline:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách công việc theo lịch.',
            error: err.message
        });
    }
});

module.exports = router;
