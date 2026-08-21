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
    '#3B82F6',
    '#EF4444'
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

function toBool(value) {
    return Number(value) === 1;
}

function mapProject(row) {
    return {
        id: row.id,
        name: row.name,
        description: row.description,
        status: row.status,
        start_date: row.start_date,
        end_date: row.end_date,
        owner_id: row.owner_id,
        project_role_id: row.project_role_id,
        role_name: row.role_name,
        color: getProjectColor(row.id),
        totalTasks: Number(row.total_tasks || 0),
        completedTasks: Number(row.completed_tasks || 0),
        members: Number(row.members || 0)
    };
}

function mapTask(row) {
    return {
        id: row.id,
        project_id: row.project_id,
        title: row.title,
        description: row.description,
        due_date: row.due_date,
        status: row.status,
        isCompleted: row.status === 'done',
        projectName: row.project_name,
        projectColor: getProjectColor(row.project_id)
    };
}

async function getCurrentUser(userId) {
    const [rows] = await pool.query(
        `SELECT u.id, u.email, u.name, u.avatar, u.created_at, u.last_login_at,
                u.system_role_id, r.name AS role_name
         FROM users u
         LEFT JOIN roles r ON r.id = u.system_role_id
         WHERE u.id = ?
         LIMIT 1`,
        [userId]
    );

    return rows[0] || null;
}

async function getProjects(userId) {
    const [rows] = await pool.query(
        `SELECT p.id, p.name, p.description, p.owner_id, p.status,
                p.start_date, p.end_date, pm.project_role_id, pr.name AS role_name,
                COUNT(DISTINCT all_pm.user_id) AS members,
                COUNT(DISTINCT t.id) AS total_tasks,
                COUNT(DISTINCT CASE WHEN t.status = 'done' THEN t.id END) AS completed_tasks
         FROM projects p
         LEFT JOIN project_members pm
                ON pm.project_id = p.id AND pm.user_id = ?
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
         LEFT JOIN tasks t ON t.project_id = p.id
         WHERE (p.owner_id = ? OR pm.user_id = ?)
           AND COALESCE(p.status, 'planning') <> 'completed'
         GROUP BY p.id, p.name, p.description, p.owner_id, p.status,
                  p.start_date, p.end_date, pm.project_role_id, pr.name
         ORDER BY p.updated_at DESC, p.created_at DESC`,
        [userId, userId, userId]
    );

    return rows.map(mapProject);
}

async function getAssignedTasks(userId) {
    const [rows] = await pool.query(
        `SELECT t.id, t.project_id, t.title, t.description, t.due_date,
                t.status, p.name AS project_name
         FROM tasks t
         INNER JOIN projects p ON p.id = t.project_id
         WHERE t.assignee_id = ?
           AND COALESCE(p.status, 'planning') <> 'completed'
         ORDER BY
            CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END,
            t.due_date ASC,
            t.created_at DESC`,
        [userId]
    );

    return rows.map(mapTask);
}

async function getNotifications(userId, limit = 10) {
    const [rows] = await pool.query(
        `SELECT id, type, content, data, \`read\`, created_at
         FROM notifications
         WHERE user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`,
        [userId, limit]
    );

    return rows.map((row) => ({
        id: row.id,
        type: row.type,
        content: row.content,
        data: row.data,
        read: toBool(row.read),
        created_at: row.created_at
    }));
}

async function getUnreadCounts(userId) {
    const [[notificationRows], [messageRows]] = await Promise.all([
        pool.query(
            'SELECT COUNT(*) AS total FROM notifications WHERE user_id = ? AND `read` = 0',
            [userId]
        ),
        pool.query(
            'SELECT COUNT(*) AS total FROM messages WHERE receiver_id = ? AND `read` = 0',
            [userId]
        )
    ]);

    return {
        notifications: Number(notificationRows[0]?.total || 0),
        messages: Number(messageRows[0]?.total || 0)
    };
}

router.use(requireAuth);

router.get('/dashboard', async (req, res) => {
    try {
        const userId = req.user.id;
        const [user, projects, tasks, notifications, unread] = await Promise.all([
            getCurrentUser(userId),
            getProjects(userId),
            getAssignedTasks(userId),
            getNotifications(userId, 5),
            getUnreadCounts(userId)
        ]);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tài khoản.'
            });
        }

        const incompleteTasks = tasks.filter((task) => !task.isCompleted);

        return res.json({
            success: true,
            data: {
                user,
                stats: {
                    totalProjects: projects.length,
                    incompleteTasks: incompleteTasks.length,
                    unreadNotifications: unread.notifications,
                    unreadMessages: unread.messages
                },
                projects,
                tasks,
                notifications
            }
        });
    } catch (err) {
        console.error('Lỗi lấy dữ liệu trang chủ:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy dữ liệu trang chủ.',
            error: err.message
        });
    }
});

router.get('/projects', async (req, res) => {
    try {
        const projects = await getProjects(req.user.id);
        return res.json({ success: true, data: projects });
    } catch (err) {
        console.error('Lỗi lấy danh sách dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách dự án.',
            error: err.message
        });
    }
});

router.get('/tasks', async (req, res) => {
    try {
        const tasks = await getAssignedTasks(req.user.id);
        return res.json({ success: true, data: tasks });
    } catch (err) {
        console.error('Lỗi lấy danh sách nhiệm vụ:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách nhiệm vụ.',
            error: err.message
        });
    }
});

router.get('/notifications', async (req, res) => {
    try {
        const notifications = await getNotifications(req.user.id, 30);
        const unread = await getUnreadCounts(req.user.id);
        return res.json({
            success: true,
            data: {
                unread: unread.notifications,
                notifications
            }
        });
    } catch (err) {
        console.error('Lỗi lấy thông báo:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy thông báo.',
            error: err.message
        });
    }
});

router.get('/messages/unread-count', async (req, res) => {
    try {
        const unread = await getUnreadCounts(req.user.id);
        return res.json({
            success: true,
            data: {
                unread: unread.messages
            }
        });
    } catch (err) {
        console.error('Lỗi lấy số tin nhắn chưa đọc:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy số tin nhắn chưa đọc.',
            error: err.message
        });
    }
});

module.exports = router;
