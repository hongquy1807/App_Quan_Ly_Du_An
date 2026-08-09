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
const ALLOWED_ATTACHMENT_TYPES = new Set(['image', 'video', 'document']);
const ALLOWED_STATUSES = new Set(['pending', 'reviewing', 'resolved', 'rejected']);

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

function normalizeText(value) {
    return String(value || '').trim();
}

function normalizeAttachments(value) {
    if (!Array.isArray(value)) return [];

    return value
        .map((item) => ({
            file_name: normalizeText(item.file_name || item.fileName || item.name),
            file_url: normalizeText(item.file_url || item.fileUrl || item.url),
            file_type: normalizeText(item.file_type || item.fileType || item.type),
            mime_type: normalizeText(item.mime_type || item.mimeType),
            file_size: item.file_size || item.fileSize || null
        }))
        .filter((item) => item.file_name && item.file_url && ALLOWED_ATTACHMENT_TYPES.has(item.file_type));
}

function mapAttachment(row) {
    return {
        id: row.id,
        feedback_id: row.feedback_id,
        file_name: row.file_name,
        file_url: row.file_url,
        file_type: row.file_type,
        mime_type: row.mime_type,
        file_size: row.file_size === null ? null : Number(row.file_size),
        created_at: row.created_at
    };
}

function mapFeedback(row, attachments = []) {
    return {
        id: row.id,
        user_id: row.user_id,
        user_name: row.user_name || null,
        user_email: row.user_email || null,
        title: row.title,
        content: row.content,
        status: row.status,
        created_at: row.created_at,
        updated_at: row.updated_at,
        attachments
    };
}

router.use(requireAuth);

// POST /api/feedback
// Tao gop y moi. Attachments la tuy chon, dung khi FE da upload file va co file_url.
router.post('/', async (req, res) => {
    const connection = await pool.getConnection();

    try {
        const userId = req.user.id;
        const title = normalizeText(req.body.title);
        const content = normalizeText(req.body.content);
        const attachments = normalizeAttachments(req.body.attachments);

        if (!title) {
            return res.status(400).json({
                success: false,
                message: 'Tiêu đề góp ý không được để trống.'
            });
        }

        if (!content) {
            return res.status(400).json({
                success: false,
                message: 'Nội dung góp ý không được để trống.'
            });
        }

        await connection.beginTransaction();

        const [result] = await connection.query(
            `INSERT INTO feedbacks (user_id, title, content, status)
             VALUES (?, ?, ?, 'pending')`,
            [userId, title, content]
        );

        const feedbackId = result.insertId;

        if (attachments.length > 0) {
            const values = attachments.map((attachment) => [
                feedbackId,
                attachment.file_name,
                attachment.file_url,
                attachment.file_type,
                attachment.mime_type || null,
                attachment.file_size
            ]);

            await connection.query(
                `INSERT INTO feedback_attachments
                    (feedback_id, file_name, file_url, file_type, mime_type, file_size)
                 VALUES ?`,
                [values]
            );
        }

        await connection.commit();

        const feedback = await getFeedbackById(feedbackId, userId);
        return res.status(201).json({
            success: true,
            message: 'Gửi góp ý thành công.',
            data: feedback
        });
    } catch (err) {
        await connection.rollback();
        console.error('Lỗi gửi góp ý:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể gửi góp ý.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

// GET /api/feedback
// Lay danh sach gop y cua user dang dang nhap.
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(100, parseInt(req.query.limit, 10) || 20);
        const offset = (page - 1) * limit;

        const [rows] = await pool.query(
            `SELECT f.id, f.user_id, u.name AS user_name, u.email AS user_email,
                    f.title, f.content, f.status, f.created_at, f.updated_at,
                    COUNT(fa.id) AS attachment_count
             FROM feedbacks f
             LEFT JOIN users u ON u.id = f.user_id
             LEFT JOIN feedback_attachments fa ON fa.feedback_id = f.id
             WHERE f.user_id = ?
             GROUP BY f.id, f.user_id, u.name, u.email, f.title, f.content,
                      f.status, f.created_at, f.updated_at
             ORDER BY f.created_at DESC
             LIMIT ? OFFSET ?`,
            [userId, limit, offset]
        );

        const [countRows] = await pool.query(
            'SELECT COUNT(*) AS total FROM feedbacks WHERE user_id = ?',
            [userId]
        );

        return res.json({
            success: true,
            data: {
                page,
                limit,
                total: Number(countRows[0]?.total || 0),
                feedbacks: rows.map((row) => ({
                    ...mapFeedback(row),
                    attachment_count: Number(row.attachment_count || 0)
                }))
            }
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách góp ý:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách góp ý.',
            error: err.message
        });
    }
});

// GET /api/feedback/:id
// Xem chi tiet mot gop y cua user dang dang nhap.
router.get('/:id', async (req, res) => {
    try {
        const feedbackId = Number(req.params.id || 0);
        if (!feedbackId) {
            return res.status(400).json({
                success: false,
                message: 'ID góp ý không hợp lệ.'
            });
        }

        const feedback = await getFeedbackById(feedbackId, req.user.id);
        if (!feedback) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy góp ý.'
            });
        }

        return res.json({
            success: true,
            data: feedback
        });
    } catch (err) {
        console.error('Lỗi lấy chi tiết góp ý:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy chi tiết góp ý.',
            error: err.message
        });
    }
});

// PATCH /api/feedback/:id/status
// Cho trang admin sau nay cap nhat trang thai gop y.
router.patch('/:id/status', async (req, res) => {
    try {
        const feedbackId = Number(req.params.id || 0);
        const status = normalizeText(req.body.status);

        if (!feedbackId) {
            return res.status(400).json({
                success: false,
                message: 'ID góp ý không hợp lệ.'
            });
        }

        if (!ALLOWED_STATUSES.has(status)) {
            return res.status(400).json({
                success: false,
                message: 'Trạng thái góp ý không hợp lệ.'
            });
        }

        const [roleRows] = await pool.query(
            'SELECT system_role_id FROM users WHERE id = ? LIMIT 1',
            [req.user.id]
        );

        if (Number(roleRows[0]?.system_role_id) !== 1) {
            return res.status(403).json({
                success: false,
                message: 'Chỉ quản trị viên mới được cập nhật trạng thái góp ý.'
            });
        }

        const [result] = await pool.query(
            'UPDATE feedbacks SET status = ? WHERE id = ?',
            [status, feedbackId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy góp ý.'
            });
        }

        const feedback = await getFeedbackById(feedbackId, null);
        return res.json({
            success: true,
            message: 'Cập nhật trạng thái góp ý thành công.',
            data: feedback
        });
    } catch (err) {
        console.error('Lỗi cập nhật trạng thái góp ý:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật trạng thái góp ý.',
            error: err.message
        });
    }
});

async function getFeedbackById(feedbackId, userId) {
    const params = [feedbackId];
    let userFilter = '';

    if (userId) {
        userFilter = 'AND f.user_id = ?';
        params.push(userId);
    }

    const [feedbackRows] = await pool.query(
        `SELECT f.id, f.user_id, u.name AS user_name, u.email AS user_email,
                f.title, f.content, f.status, f.created_at, f.updated_at
         FROM feedbacks f
         LEFT JOIN users u ON u.id = f.user_id
         WHERE f.id = ? ${userFilter}
         LIMIT 1`,
        params
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

    return mapFeedback(
        feedbackRows[0],
        attachmentRows.map(mapAttachment)
    );
}

module.exports = router;
