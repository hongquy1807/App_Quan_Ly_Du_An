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

function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase();
}

function mapFriend(row) {
    return {
        id: row.friendship_id,
        user_id: row.user_id,
        name: row.name,
        email: row.email,
        avatar: row.avatar,
        friends_since: row.friends_since
    };
}

router.use(requireAuth);

// GET /api/friends?search=&sort=asc|desc
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const search = String(req.query.search || '').trim();
        const sort = String(req.query.sort || 'asc').toLowerCase() === 'desc' ? 'DESC' : 'ASC';
        const keyword = `%${search}%`;

        const [rows] = await pool.query(
            `SELECT
                f.id AS friendship_id,
                CASE
                    WHEN f.requester_id = ? THEN u2.id
                    ELSE u1.id
                END AS user_id,
                CASE
                    WHEN f.requester_id = ? THEN u2.name
                    ELSE u1.name
                END AS name,
                CASE
                    WHEN f.requester_id = ? THEN u2.email
                    ELSE u1.email
                END AS email,
                CASE
                    WHEN f.requester_id = ? THEN u2.avatar
                    ELSE u1.avatar
                END AS avatar,
                COALESCE(f.responded_at, f.updated_at, f.requested_at) AS friends_since
             FROM friendships f
             JOIN users u1 ON u1.id = f.requester_id
             JOIN users u2 ON u2.id = f.addressee_id
             WHERE f.status = 'accepted'
               AND (f.requester_id = ? OR f.addressee_id = ?)
               AND (
                    ? = ''
                    OR u1.name LIKE ?
                    OR u1.email LIKE ?
                    OR u2.name LIKE ?
                    OR u2.email LIKE ?
               )
             ORDER BY name ${sort}`,
            [userId, userId, userId, userId, userId, userId, search, keyword, keyword, keyword, keyword]
        );

        return res.json({
            success: true,
            data: {
                friends: rows.map(mapFriend),
                total: rows.length
            }
        });
    } catch (err) {
        console.error('Friends list error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tải danh sách bạn bè. Kiểm tra bảng friendships đã được tạo chưa.'
        });
    }
});

// POST /api/friends/requests
// Body: { "email": "friend@email.com" }
router.post('/requests', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const requesterId = req.user.id;
        const email = normalizeEmail(req.body.email);

        if (!email) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập email người bạn muốn kết bạn.'
            });
        }

        const [users] = await connection.query(
            `SELECT id, name, email FROM users WHERE LOWER(email) = ? LIMIT 1`,
            [email]
        );
        const addressee = users[0];
        if (!addressee) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy người dùng với email này.'
            });
        }

        if (Number(addressee.id) === Number(requesterId)) {
            return res.status(400).json({
                success: false,
                message: 'Bạn không thể gửi lời mời kết bạn cho chính mình.'
            });
        }

        await connection.beginTransaction();

        const [existingRows] = await connection.query(
            `SELECT id, requester_id, addressee_id, status
             FROM friendships
             WHERE (requester_id = ? AND addressee_id = ?)
                OR (requester_id = ? AND addressee_id = ?)
             LIMIT 1
             FOR UPDATE`,
            [requesterId, addressee.id, addressee.id, requesterId]
        );

        const existing = existingRows[0];
        if (existing) {
            if (existing.status === 'accepted') {
                await connection.rollback();
                return res.status(409).json({
                    success: false,
                    message: 'Hai bạn đã là bạn bè.'
                });
            }

            if (existing.status === 'pending') {
                await connection.rollback();
                return res.status(409).json({
                    success: false,
                    message: 'Lời mời kết bạn đang chờ phản hồi.'
                });
            }

            await connection.query(
                `UPDATE friendships
                 SET requester_id = ?,
                     addressee_id = ?,
                     status = 'pending',
                     requested_at = NOW(),
                     responded_at = NULL
                 WHERE id = ?`,
                [requesterId, addressee.id, existing.id]
            );
        } else {
            await connection.query(
                `INSERT INTO friendships (requester_id, addressee_id, status)
                 VALUES (?, ?, 'pending')`,
                [requesterId, addressee.id]
            );
        }

        await connection.query(
            `INSERT INTO notifications (user_id, type, content, data)
             VALUES (?, 'friend_request', ?, JSON_OBJECT('requester_id', ?))`,
            [
                addressee.id,
                'Bạn có một lời mời kết bạn mới.',
                requesterId
            ]
        );

        await connection.commit();
        return res.status(201).json({
            success: true,
            message: 'Đã gửi lời mời kết bạn.',
            data: {
                user_id: addressee.id,
                name: addressee.name,
                email: addressee.email
            }
        });
    } catch (err) {
        await connection.rollback();
        console.error('Send friend request error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể gửi lời mời kết bạn.'
        });
    } finally {
        connection.release();
    }
});

// GET /api/friends/requests/incoming
router.get('/requests/incoming', async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT f.id, f.requested_at, u.id AS user_id, u.name, u.email, u.avatar
             FROM friendships f
             JOIN users u ON u.id = f.requester_id
             WHERE f.addressee_id = ? AND f.status = 'pending'
             ORDER BY f.requested_at DESC`,
            [req.user.id]
        );

        return res.json({
            success: true,
            data: {
                requests: rows
            }
        });
    } catch (err) {
        console.error('Incoming friend requests error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tải lời mời kết bạn.'
        });
    }
});

// PATCH /api/friends/requests/:id/accept
router.patch('/requests/:id/accept', async (req, res) => {
    try {
        const [result] = await pool.query(
            `UPDATE friendships
             SET status = 'accepted', responded_at = NOW()
             WHERE id = ? AND addressee_id = ? AND status = 'pending'`,
            [req.params.id, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy lời mời cần chấp nhận.'
            });
        }

        return res.json({
            success: true,
            message: 'Đã chấp nhận lời mời kết bạn.'
        });
    } catch (err) {
        console.error('Accept friend request error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể chấp nhận lời mời kết bạn.'
        });
    }
});

// PATCH /api/friends/requests/:id/reject
router.patch('/requests/:id/reject', async (req, res) => {
    try {
        const [result] = await pool.query(
            `UPDATE friendships
             SET status = 'rejected', responded_at = NOW()
             WHERE id = ? AND addressee_id = ? AND status = 'pending'`,
            [req.params.id, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy lời mời cần từ chối.'
            });
        }

        return res.json({
            success: true,
            message: 'Đã từ chối lời mời kết bạn.'
        });
    } catch (err) {
        console.error('Reject friend request error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể từ chối lời mời kết bạn.'
        });
    }
});

module.exports = router;
