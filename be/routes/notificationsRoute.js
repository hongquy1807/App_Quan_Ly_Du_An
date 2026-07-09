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

function getBearerToken(req) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return null;
    return authHeader.slice(7).trim();
}

function requireAuth(req, res, next) {
    try {
        const token = getBearerToken(req);
        if (!token) {
            return res.status(401).json({ success: false, message: 'Bạn chưa đăng nhập.' });
        }

        req.user = jwt.verify(token, JWT_SECRET);
        next();
    } catch (err) {
        return res.status(401).json({ success: false, message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.' });
    }
}

function toBool(value) {
    return Number(value) === 1;
}

router.use(requireAuth);

// GET / - list notifications with optional filters: ?page=1&limit=20&read=0
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, parseInt(req.query.limit) || 20);
        const offset = (page - 1) * limit;
        const readFilter = req.query.read; // '0' or '1' or undefined

        let where = 'WHERE user_id = ?';
        const params = [userId];
        if (readFilter === '0' || readFilter === '1') {
            where += ' AND `read` = ?';
            params.push(readFilter);
        }

        const [rows] = await pool.query(
            `SELECT id, type, content, data, ` + '`read`' + ` AS read, created_at
             FROM notifications
             ${where}
             ORDER BY created_at DESC
             LIMIT ? OFFSET ?`,
            params.concat([limit, offset])
        );

        const [countRows] = await pool.query(
            `SELECT COUNT(*) AS total FROM notifications ${where}`,
            params
        );

        return res.json({
            success: true,
            data: {
                page,
                limit,
                total: Number(countRows[0]?.total || 0),
                notifications: rows.map(r => ({
                    id: r.id,
                    type: r.type,
                    content: r.content,
                    data: r.data,
                    read: toBool(r.read),
                    created_at: r.created_at
                }))
            }
        });
    } catch (err) {
        console.error('Lỗi lấy thông báo:', err);
        return res.status(500).json({ success: false, message: 'Không thể lấy thông báo.', error: err.message });
    }
});

// GET /unread-count
router.get('/unread-count', async (req, res) => {
    try {
        const userId = req.user.id;
        const [rows] = await pool.query('SELECT COUNT(*) AS total FROM notifications WHERE user_id = ? AND `read` = 0', [userId]);
        return res.json({ success: true, data: { unread: Number(rows[0]?.total || 0) } });
    } catch (err) {
        console.error('Lỗi lấy số thông báo chưa đọc:', err);
        return res.status(500).json({ success: false, message: 'Không thể lấy số thông báo chưa đọc.', error: err.message });
    }
});

// GET /:id
router.get('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);
        const [rows] = await pool.query('SELECT id, type, content, data, `read`, created_at FROM notifications WHERE id = ? AND user_id = ? LIMIT 1', [id, userId]);
        if (!rows[0]) return res.status(404).json({ success: false, message: 'Không tìm thấy thông báo.' });
        const r = rows[0];
        return res.json({ success: true, data: { id: r.id, type: r.type, content: r.content, data: r.data, read: toBool(r.read), created_at: r.created_at } });
    } catch (err) {
        console.error('Lỗi lấy thông báo:', err);
        return res.status(500).json({ success: false, message: 'Không thể lấy thông báo.', error: err.message });
    }
});

// POST / - create notification (may be used by admin/services)
router.post('/', async (req, res) => {
    try {
        const { user_id, type = 'general', content, data = null } = req.body;
        if (!user_id || !content) {
            return res.status(400).json({ success: false, message: 'Thiếu user_id hoặc content.' });
        }

        const [result] = await pool.query('INSERT INTO notifications (user_id, type, content, data) VALUES (?, ?, ?, ?)', [user_id, type, content, data ? JSON.stringify(data) : null]);
        return res.status(201).json({ success: true, data: { id: result.insertId } });
    } catch (err) {
        console.error('Lỗi tạo thông báo:', err);
        return res.status(500).json({ success: false, message: 'Không thể tạo thông báo.', error: err.message });
    }
});

// PATCH /:id/read - mark read/unread
router.patch('/:id/read', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);
        const read = req.body.read === true ? 1 : 0;
        const [result] = await pool.query('UPDATE notifications SET `read` = ? WHERE id = ? AND user_id = ?', [read, id, userId]);
        if (result.affectedRows === 0) return res.status(404).json({ success: false, message: 'Không tìm thấy thông báo.' });
        return res.json({ success: true, data: { id, read: Boolean(read) } });
    } catch (err) {
        console.error('Lỗi cập nhật trạng thái thông báo:', err);
        return res.status(500).json({ success: false, message: 'Không thể cập nhật trạng thái thông báo.', error: err.message });
    }
});

// PATCH /mark-all-read
router.patch('/mark-all-read', async (req, res) => {
    try {
        const userId = req.user.id;
        const [result] = await pool.query('UPDATE notifications SET `read` = 1 WHERE user_id = ? AND `read` = 0', [userId]);
        return res.json({ success: true, data: { marked: Number(result.affectedRows || 0) } });
    } catch (err) {
        console.error('Lỗi đánh dấu tất cả đã đọc:', err);
        return res.status(500).json({ success: false, message: 'Không thể đánh dấu tất cả thông báo đã đọc.', error: err.message });
    }
});

// DELETE /:id
router.delete('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const id = Number(req.params.id || 0);
        const [result] = await pool.query('DELETE FROM notifications WHERE id = ? AND user_id = ?', [id, userId]);
        if (result.affectedRows === 0) return res.status(404).json({ success: false, message: 'Không tìm thấy thông báo.' });
        return res.json({ success: true });
    } catch (err) {
        console.error('Lỗi xóa thông báo:', err);
        return res.status(500).json({ success: false, message: 'Không thể xóa thông báo.', error: err.message });
    }
});

module.exports = router;
