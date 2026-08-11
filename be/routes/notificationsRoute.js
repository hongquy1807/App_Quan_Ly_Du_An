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
const DEADLINE_REMINDER_DAYS = [3, 2, 1];

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
    return Number(value) === 1 || value === true;
}

function safeJson(value) {
    if (!value) return {};
    if (typeof value === 'object') return value;
    try {
        return JSON.parse(value);
    } catch (err) {
        return {};
    }
}

function formatRelativeTime(value) {
    const createdAt = new Date(value);
    if (Number.isNaN(createdAt.getTime())) return '';

    const diffMs = Date.now() - createdAt.getTime();
    const minute = 60 * 1000;
    const hour = 60 * minute;
    const day = 24 * hour;

    if (diffMs < minute) return 'Vừa xong';
    if (diffMs < hour) return `${Math.max(1, Math.floor(diffMs / minute))} phút trước`;
    if (diffMs < day) return `${Math.floor(diffMs / hour)} giờ trước`;
    if (diffMs < 2 * day) return 'Hôm qua';
    return `${Math.floor(diffMs / day)} ngày trước`;
}

function notificationTitle(type, data) {
    if (type === 'deadline') {
        return Number(data.days_left) === 1 ? 'Task sắp đến hạn' : 'Nhắc hạn nhiệm vụ';
    }
    if (type === 'task') {
        if (data.action === 'completed') return 'Nhiệm vụ đã hoàn thành';
        return 'Bạn có nhiệm vụ mới';
    }
    if (type === 'project_invitation') return 'Bạn được mời tham gia dự án';
    if (type === 'project_message') return 'Bạn có tin nhắn mới';
    if (type === 'project') return 'Cập nhật dự án';
    return 'Thông báo';
}

function screenForNotification(type, data) {
    if ((type === 'deadline' || type === 'task') && data.task_id) return 'task_detail';
    if (type === 'project_invitation') return 'project_invitations';
    if (type === 'project_message') return 'project_chat';
    if (data.project_id) return 'project_detail';
    return null;
}

function notificationProject(row, data) {
    return row.project_name || data.project_name || '';
}

function mapNotification(row) {
    const data = safeJson(row.data);
    const type = row.type || 'general';
    const projectName = notificationProject(row, data);

    return {
        id: row.id,
        type,
        title: notificationTitle(type, data),
        message: row.content,
        content: row.content,
        project: projectName,
        time: formatRelativeTime(row.created_at),
        isUnread: !toBool(row.read),
        read: toBool(row.read),
        created_at: row.created_at,
        data,
        project_id: data.project_id || row.project_id || null,
        task_id: data.task_id || null,
        invitation_id: data.invitation_id || null,
        message_id: data.message_id || null,
        screen: screenForNotification(type, data)
    };
}

async function createDeadlineReminders(userId) {
    const placeholders = DEADLINE_REMINDER_DAYS.map(() => '?').join(', ');
    const [tasks] = await pool.query(
        `SELECT DISTINCT
                t.id,
                t.title,
                t.project_id,
                t.due_date,
                p.name AS project_name,
                DATEDIFF(t.due_date, CURDATE()) AS days_left
         FROM tasks t
         INNER JOIN projects p ON p.id = t.project_id
         INNER JOIN project_members pm ON pm.project_id = t.project_id
         WHERE pm.user_id = ?
           AND p.status <> 'completed'
           AND (t.assignee_id = ? OR t.assignee_id IS NULL)
           AND COALESCE(t.status, 'todo') <> 'done'
           AND t.due_date IS NOT NULL
           AND DATEDIFF(t.due_date, CURDATE()) IN (${placeholders})`,
        [userId, userId, ...DEADLINE_REMINDER_DAYS]
    );

    for (const task of tasks) {
        const payload = {
            task_id: task.id,
            project_id: task.project_id,
            project_name: task.project_name,
            days_left: Number(task.days_left),
            reminder_date: new Date().toISOString().slice(0, 10)
        };

        const [existingRows] = await pool.query(
            `SELECT id
             FROM notifications
             WHERE user_id = ?
               AND type = 'deadline'
               AND JSON_UNQUOTE(JSON_EXTRACT(data, '$.task_id')) = ?
               AND JSON_UNQUOTE(JSON_EXTRACT(data, '$.days_left')) = ?
               AND JSON_UNQUOTE(JSON_EXTRACT(data, '$.reminder_date')) = ?
             LIMIT 1`,
            [
                userId,
                String(payload.task_id),
                String(payload.days_left),
                payload.reminder_date
            ]
        );

        if (existingRows.length > 0) continue;

        const dayText = payload.days_left === 1 ? '1 ngày' : `${payload.days_left} ngày`;
        await pool.query(
            `INSERT INTO notifications (user_id, type, content, data, \`read\`)
             VALUES (?, 'deadline', ?, ?, 0)`,
            [
                userId,
                `${task.title} còn ${dayText} đến hạn.`,
                JSON.stringify(payload)
            ]
        );
    }
}

router.use(requireAuth);

router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
        const offset = (page - 1) * limit;
        const readFilter = req.query.read;

        await createDeadlineReminders(userId);

        let where = 'WHERE n.user_id = ?';
        const params = [userId];
        if (readFilter === '0' || readFilter === '1') {
            where += ' AND n.`read` = ?';
            params.push(Number(readFilter));
        }

        const [rows] = await pool.query(
            `SELECT
                    n.id,
                    n.type,
                    n.content,
                    n.data,
                    n.\`read\` AS \`read\`,
                    n.created_at,
                    p.id AS project_id,
                    p.name AS project_name
             FROM notifications n
             LEFT JOIN projects p
                ON p.id = CAST(JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.project_id')) AS UNSIGNED)
             ${where}
             ORDER BY n.created_at DESC, n.id DESC
             LIMIT ? OFFSET ?`,
            [...params, limit, offset]
        );

        const [countRows] = await pool.query(
            `SELECT COUNT(*) AS total FROM notifications n ${where}`,
            params
        );

        const unread = rows.filter((row) => !toBool(row.read)).length;
        return res.json({
            success: true,
            data: {
                page,
                limit,
                total: Number(countRows[0]?.total || 0),
                unread,
                notifications: rows.map(mapNotification)
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

router.get('/unread-count', async (req, res) => {
    try {
        const userId = req.user.id;
        await createDeadlineReminders(userId);

        const [rows] = await pool.query(
            'SELECT COUNT(*) AS total FROM notifications WHERE user_id = ? AND `read` = 0',
            [userId]
        );

        return res.json({
            success: true,
            data: { unread: Number(rows[0]?.total || 0) }
        });
    } catch (err) {
        console.error('Lỗi lấy số thông báo chưa đọc:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy số thông báo chưa đọc.',
            error: err.message
        });
    }
});

router.patch('/mark-all-read', async (req, res) => {
    try {
        const userId = req.user.id;
        const [result] = await pool.query(
            'UPDATE notifications SET `read` = 1 WHERE user_id = ? AND `read` = 0',
            [userId]
        );

        return res.json({
            success: true,
            data: { marked: Number(result.affectedRows || 0) }
        });
    } catch (err) {
        console.error('Lỗi đánh dấu tất cả đã đọc:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể đánh dấu tất cả thông báo đã đọc.',
            error: err.message
        });
    }
});

router.get('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);

        const [rows] = await pool.query(
            `SELECT
                    n.id,
                    n.type,
                    n.content,
                    n.data,
                    n.\`read\` AS \`read\`,
                    n.created_at,
                    p.id AS project_id,
                    p.name AS project_name
             FROM notifications n
             LEFT JOIN projects p
                ON p.id = CAST(JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.project_id')) AS UNSIGNED)
             WHERE n.id = ? AND n.user_id = ?
             LIMIT 1`,
            [id, userId]
        );

        if (!rows[0]) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy thông báo.'
            });
        }

        return res.json({
            success: true,
            data: mapNotification(rows[0])
        });
    } catch (err) {
        console.error('Lỗi lấy chi tiết thông báo:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy chi tiết thông báo.',
            error: err.message
        });
    }
});

router.post('/', async (req, res) => {
    try {
        const { user_id, type = 'general', content, data = null } = req.body;
        if (!user_id || !content) {
            return res.status(400).json({
                success: false,
                message: 'Thiếu user_id hoặc content.'
            });
        }

        const [result] = await pool.query(
            'INSERT INTO notifications (user_id, type, content, data, `read`) VALUES (?, ?, ?, ?, 0)',
            [user_id, type, content, data ? JSON.stringify(data) : null]
        );

        return res.status(201).json({
            success: true,
            data: { id: result.insertId }
        });
    } catch (err) {
        console.error('Lỗi tạo thông báo:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tạo thông báo.',
            error: err.message
        });
    }
});

router.patch('/:id/read', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);
        const read = req.body.read === false || req.body.read === 0 || req.body.read === '0' ? 0 : 1;

        const [result] = await pool.query(
            'UPDATE notifications SET `read` = ? WHERE id = ? AND user_id = ?',
            [read, id, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy thông báo.'
            });
        }

        return res.json({
            success: true,
            data: { id, read: Boolean(read) }
        });
    } catch (err) {
        console.error('Lỗi cập nhật trạng thái thông báo:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật trạng thái thông báo.',
            error: err.message
        });
    }
});

router.delete('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);

        const [result] = await pool.query(
            'DELETE FROM notifications WHERE id = ? AND user_id = ?',
            [id, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy thông báo.'
            });
        }

        return res.json({ success: true });
    } catch (err) {
        console.error('Lỗi xóa thông báo:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa thông báo.',
            error: err.message
        });
    }
});

module.exports = router;
