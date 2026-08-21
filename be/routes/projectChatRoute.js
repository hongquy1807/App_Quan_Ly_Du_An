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
const ALLOWED_MESSAGE_TYPES = ['text', 'image', 'video', 'file'];

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

function mapProject(row) {
    return {
        id: row.id,
        name: row.name,
        description: row.description,
        owner_id: row.owner_id,
        status: row.status,
        member_count: Number(row.member_count || 0),
        last_message: row.last_message_id
            ? {
                id: row.last_message_id,
                content: row.last_message_content,
                message_type: row.last_message_type,
                sender_id: row.last_sender_id,
                sender_name: row.last_sender_name,
                created_at: row.last_message_created_at
            }
            : null,
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapMessage(row, currentUserId) {
    return {
        id: row.id,
        project_id: row.project_id,
        sender_id: row.sender_id,
        sender_name: row.sender_name,
        sender_email: row.sender_email,
        sender_avatar: row.sender_avatar,
        content: row.content,
        message_type: row.message_type,
        file_url: row.file_url,
        file_name: row.file_name,
        file_size: row.file_size,
        is_mine: Number(row.sender_id) === Number(currentUserId),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapDirectFriend(row) {
    return {
        id: row.user_id,
        name: row.name,
        email: row.email,
        avatar: row.avatar,
        conversation_id: row.conversation_id,
        member_count: 2,
        last_message: row.last_message_id
            ? {
                id: row.last_message_id,
                content: row.last_message_content,
                sender_id: row.last_sender_id,
                sender_name: row.last_sender_name,
                created_at: row.last_message_created_at
            }
            : null
    };
}

function mapDirectMessage(row, currentUserId) {
    return {
        id: row.id,
        conversation_id: row.conversation_id,
        sender_id: row.sender_id,
        sender_name: row.sender_name,
        sender_email: row.sender_email,
        sender_avatar: row.sender_avatar,
        receiver_id: row.receiver_id,
        content: row.content,
        message_type: row.file_type || 'text',
        file_url: row.file_url,
        is_mine: Number(row.sender_id) === Number(currentUserId),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

async function getProjectForUser(projectId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT p.id, p.name, p.description, p.owner_id, p.status, p.created_at, p.updated_at
         FROM projects p
         INNER JOIN project_members pm
                 ON pm.project_id = p.id AND pm.user_id = ?
         WHERE p.id = ?
           AND COALESCE(p.status, 'planning') <> 'completed'
         LIMIT 1`,
        [userId, projectId]
    );

    return rows[0] || null;
}

router.use(requireAuth);

async function getAcceptedFriend(friendId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT u.id, u.name, u.email, u.avatar
         FROM friendships f
         INNER JOIN users u
                 ON u.id = CASE
                    WHEN f.requester_id = ? THEN f.addressee_id
                    ELSE f.requester_id
                 END
         WHERE f.status = 'accepted'
           AND ((f.requester_id = ? AND f.addressee_id = ?)
             OR (f.requester_id = ? AND f.addressee_id = ?))
         LIMIT 1`,
        [userId, userId, friendId, friendId, userId]
    );

    return rows[0] || null;
}

async function getOrCreateDirectConversation(userId, friendId, connection) {
    const userOneId = Math.min(Number(userId), Number(friendId));
    const userTwoId = Math.max(Number(userId), Number(friendId));

    const [existingRows] = await connection.query(
        `SELECT dc.conversation_id
         FROM direct_conversations dc
         WHERE dc.user_one_id = ? AND dc.user_two_id = ?
         LIMIT 1
         FOR UPDATE`,
        [userOneId, userTwoId]
    );

    if (existingRows[0]) return existingRows[0].conversation_id;

    const [conversationResult] = await connection.query(
        `INSERT INTO conversations (type)
         VALUES ('direct')`
    );
    const conversationId = conversationResult.insertId;

    await connection.query(
        `INSERT INTO direct_conversations (conversation_id, user_one_id, user_two_id)
         VALUES (?, ?, ?)`,
        [conversationId, userOneId, userTwoId]
    );

    await connection.query(
        `INSERT INTO conversation_members (conversation_id, user_id)
         VALUES (?, ?), (?, ?)`,
        [conversationId, userOneId, conversationId, userTwoId]
    );

    return conversationId;
}

// GET /api/project-chat/friends
// Danh sách bạn bè để nhắn tin riêng.
router.get('/friends', async (req, res) => {
    try {
        const userId = req.user.id;
        const [rows] = await pool.query(
            `SELECT
                CASE WHEN f.requester_id = ? THEN u2.id ELSE u1.id END AS user_id,
                CASE WHEN f.requester_id = ? THEN u2.name ELSE u1.name END AS name,
                CASE WHEN f.requester_id = ? THEN u2.email ELSE u1.email END AS email,
                CASE WHEN f.requester_id = ? THEN u2.avatar ELSE u1.avatar END AS avatar,
                dc.conversation_id,
                lm.id AS last_message_id,
                lm.content AS last_message_content,
                lm.sender_id AS last_sender_id,
                sender.name AS last_sender_name,
                lm.created_at AS last_message_created_at
             FROM friendships f
             INNER JOIN users u1 ON u1.id = f.requester_id
             INNER JOIN users u2 ON u2.id = f.addressee_id
             LEFT JOIN direct_conversations dc
                    ON dc.user_one_id = LEAST(f.requester_id, f.addressee_id)
                   AND dc.user_two_id = GREATEST(f.requester_id, f.addressee_id)
             LEFT JOIN messages lm
                    ON lm.id = (
                        SELECT m.id
                        FROM messages m
                        WHERE m.conversation_id = dc.conversation_id
                        ORDER BY m.created_at DESC, m.id DESC
                        LIMIT 1
                    )
             LEFT JOIN users sender ON sender.id = lm.sender_id
             WHERE f.status = 'accepted'
               AND (f.requester_id = ? OR f.addressee_id = ?)
             ORDER BY COALESCE(lm.created_at, f.responded_at, f.updated_at, f.requested_at) DESC`,
            [userId, userId, userId, userId, userId, userId]
        );

        return res.json({
            success: true,
            data: rows.map(mapDirectFriend)
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách bạn bè chat:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách bạn bè để nhắn tin.',
            error: err.message
        });
    }
});

// GET /api/project-chat/direct/:friendId/messages
router.get('/direct/:friendId/messages', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const friendId = Number(req.params.friendId);
        const limit = Math.min(Math.max(Number(req.query.limit || 50), 1), 100);

        if (!friendId) {
            return res.status(400).json({
                success: false,
                message: 'ID bạn bè không hợp lệ.'
            });
        }

        const friend = await getAcceptedFriend(friendId, userId, connection);
        if (!friend) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy bạn bè hoặc hai bạn chưa kết bạn.'
            });
        }

        await connection.beginTransaction();
        const conversationId = await getOrCreateDirectConversation(userId, friendId, connection);
        const [rows] = await connection.query(
            `SELECT m.id, m.conversation_id, m.sender_id, sender.name AS sender_name,
                    sender.email AS sender_email, sender.avatar AS sender_avatar,
                    m.receiver_id, m.content, m.file_url, m.file_type,
                    m.created_at, m.updated_at
             FROM messages m
             INNER JOIN users sender ON sender.id = m.sender_id
             WHERE m.conversation_id = ?
             ORDER BY m.created_at DESC, m.id DESC
             LIMIT ?`,
            [conversationId, limit]
        );

        await connection.query(
            `UPDATE messages
             SET \`read\` = 1
             WHERE conversation_id = ? AND receiver_id = ?`,
            [conversationId, userId]
        );

        await connection.commit();
        return res.json({
            success: true,
            data: {
                friend: {
                    ...friend,
                    conversation_id: conversationId
                },
                messages: rows.reverse().map((row) => mapDirectMessage(row, userId))
            }
        });
    } catch (err) {
        try {
            await connection.rollback();
        } catch (_) {}
        console.error('Lỗi lấy tin nhắn bạn bè:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy tin nhắn bạn bè.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

// POST /api/project-chat/direct/:friendId/messages
router.post('/direct/:friendId/messages', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const friendId = Number(req.params.friendId);
        const content = String(req.body.content || '').trim();
        const fileUrl = String(req.body.file_url || '').trim() || null;
        const fileType = String(req.body.file_type || '').trim() || null;

        if (!friendId) {
            return res.status(400).json({
                success: false,
                message: 'ID bạn bè không hợp lệ.'
            });
        }

        if (!content && !fileUrl) {
            return res.status(400).json({
                success: false,
                message: 'Tin nhắn không được để trống.'
            });
        }

        await connection.beginTransaction();
        const friend = await getAcceptedFriend(friendId, userId, connection);
        if (!friend) {
            await connection.rollback();
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy bạn bè hoặc hai bạn chưa kết bạn.'
            });
        }

        const conversationId = await getOrCreateDirectConversation(userId, friendId, connection);
        const [result] = await connection.query(
            `INSERT INTO messages (conversation_id, sender_id, receiver_id, content, file_url, file_type)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [conversationId, userId, friendId, content || '', fileUrl, fileType]
        );

        await connection.query(
            `UPDATE conversations
             SET updated_at = NOW()
             WHERE id = ?`,
            [conversationId]
        );

        await connection.query(
            `INSERT INTO notifications (user_id, type, content, data, \`read\`)
             VALUES (?, 'direct_message', ?, JSON_OBJECT('friend_id', ?, 'message_id', ?), 0)`,
            [friendId, 'Bạn có một tin nhắn mới.', userId, result.insertId]
        );

        const [rows] = await connection.query(
            `SELECT m.id, m.conversation_id, m.sender_id, sender.name AS sender_name,
                    sender.email AS sender_email, sender.avatar AS sender_avatar,
                    m.receiver_id, m.content, m.file_url, m.file_type,
                    m.created_at, m.updated_at
             FROM messages m
             INNER JOIN users sender ON sender.id = m.sender_id
             WHERE m.id = ?
             LIMIT 1`,
            [result.insertId]
        );

        await connection.commit();
        return res.status(201).json({
            success: true,
            message: 'Gửi tin nhắn thành công.',
            data: mapDirectMessage(rows[0], userId)
        });
    } catch (err) {
        try {
            await connection.rollback();
        } catch (_) {}
        console.error('Lỗi gửi tin nhắn bạn bè:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể gửi tin nhắn bạn bè.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

// GET /api/project-chat/projects
// Danh sách dự án mà user đang tham gia để hiển thị ở trang Tin nhắn.
router.get('/projects', async (req, res) => {
    try {
        const userId = req.user.id;

        const [rows] = await pool.query(
            `SELECT p.id, p.name, p.description, p.owner_id, p.status, p.created_at, p.updated_at,
                    COUNT(DISTINCT all_pm.user_id) AS member_count,
                    lm.id AS last_message_id,
                    lm.content AS last_message_content,
                    lm.message_type AS last_message_type,
                    lm.sender_id AS last_sender_id,
                    sender.name AS last_sender_name,
                    lm.created_at AS last_message_created_at
             FROM projects p
             INNER JOIN project_members pm
                     ON pm.project_id = p.id AND pm.user_id = ?
             LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
             LEFT JOIN project_messages lm
                    ON lm.id = (
                        SELECT pmg.id
                        FROM project_messages pmg
                        WHERE pmg.project_id = p.id
                          AND pmg.deleted_at IS NULL
                        ORDER BY pmg.created_at DESC, pmg.id DESC
                        LIMIT 1
                    )
             LEFT JOIN users sender ON sender.id = lm.sender_id
             WHERE COALESCE(p.status, 'planning') <> 'completed'
             GROUP BY p.id, p.name, p.description, p.owner_id, p.status, p.created_at, p.updated_at,
                      lm.id, lm.content, lm.message_type, lm.sender_id, sender.name, lm.created_at
             ORDER BY COALESCE(lm.created_at, p.updated_at, p.created_at) DESC`,
            [userId]
        );

        return res.json({
            success: true,
            data: rows.map(mapProject)
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách dự án chat:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách dự án chat.',
            error: err.message
        });
    }
});

// GET /api/project-chat/:projectId/messages
// Lấy tin nhắn của một dự án. Chỉ thành viên dự án mới được xem.
router.get('/:projectId/messages', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.projectId);
        const limit = Math.min(Math.max(Number(req.query.limit || 50), 1), 100);
        const beforeId = Number(req.query.before_id || 0);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const project = await getProjectForUser(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án hoặc bạn không có quyền xem tin nhắn.'
            });
        }

        const values = [projectId];
        let beforeClause = '';
        if (beforeId > 0) {
            beforeClause = 'AND pm.id < ?';
            values.push(beforeId);
        }
        values.push(limit);

        const [rows] = await pool.query(
            `SELECT pm.id, pm.project_id, pm.sender_id, u.name AS sender_name,
                    u.email AS sender_email, u.avatar AS sender_avatar,
                    pm.content, pm.message_type, pm.file_url, pm.file_name,
                    pm.file_size, pm.created_at, pm.updated_at
             FROM project_messages pm
             INNER JOIN users u ON u.id = pm.sender_id
             WHERE pm.project_id = ?
               AND pm.deleted_at IS NULL
               ${beforeClause}
             ORDER BY pm.created_at DESC, pm.id DESC
             LIMIT ?`,
            values
        );

        return res.json({
            success: true,
            data: {
                project,
                messages: rows
                    .reverse()
                    .map((row) => mapMessage(row, userId))
            }
        });
    } catch (err) {
        console.error('Lỗi lấy tin nhắn dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy tin nhắn dự án.',
            error: err.message
        });
    }
});

// POST /api/project-chat/:projectId/messages
// Gửi tin nhắn vào nhóm chat của dự án. Tất cả thành viên dự án đều xem được.
router.post('/:projectId/messages', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.projectId);
        const content = String(req.body.content || '').trim();
        const messageType = String(req.body.message_type || req.body.type || 'text').trim();
        const fileUrl = String(req.body.file_url || '').trim() || null;
        const fileName = String(req.body.file_name || '').trim() || null;
        const fileSize = Number.isFinite(Number(req.body.file_size))
            ? Number(req.body.file_size)
            : null;

        if (!projectId) {
            connection.release();
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        if (!ALLOWED_MESSAGE_TYPES.includes(messageType)) {
            connection.release();
            return res.status(400).json({
                success: false,
                message: 'Loại tin nhắn không hợp lệ.'
            });
        }

        if (!content && !fileUrl) {
            connection.release();
            return res.status(400).json({
                success: false,
                message: 'Tin nhắn không được để trống.'
            });
        }

        await connection.beginTransaction();

        const project = await getProjectForUser(projectId, userId, connection);
        if (!project) {
            await connection.rollback();
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án hoặc bạn không có quyền gửi tin nhắn.'
            });
        }

        const [result] = await connection.query(
            `INSERT INTO project_messages
                (project_id, sender_id, content, message_type, file_url, file_name, file_size)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [projectId, userId, content || null, messageType, fileUrl, fileName, fileSize]
        );

        const [memberRows] = await connection.query(
            `SELECT user_id
             FROM project_members
             WHERE project_id = ? AND user_id <> ?`,
            [projectId, userId]
        );

        if (memberRows.length > 0) {
            const notificationValues = memberRows.map((member) => [
                member.user_id,
                'project_message',
                `Bạn có tin nhắn mới ở dự án ${project.name}.`,
                JSON.stringify({ project_id: projectId, message_id: result.insertId }),
                0
            ]);

            await connection.query(
                `INSERT INTO notifications (user_id, type, content, data, \`read\`)
                 VALUES ?`,
                [notificationValues]
            );
        }

        const [rows] = await connection.query(
            `SELECT pm.id, pm.project_id, pm.sender_id, u.name AS sender_name,
                    u.email AS sender_email, u.avatar AS sender_avatar,
                    pm.content, pm.message_type, pm.file_url, pm.file_name,
                    pm.file_size, pm.created_at, pm.updated_at
             FROM project_messages pm
             INNER JOIN users u ON u.id = pm.sender_id
             WHERE pm.id = ?
             LIMIT 1`,
            [result.insertId]
        );

        await connection.commit();

        return res.status(201).json({
            success: true,
            message: 'Gửi tin nhắn thành công.',
            data: mapMessage(rows[0], userId)
        });
    } catch (err) {
        try {
            await connection.rollback();
        } catch (_) {}
        console.error('Lỗi gửi tin nhắn dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể gửi tin nhắn dự án.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

// DELETE /api/project-chat/messages/:messageId
// Xóa mềm tin nhắn của chính mình.
router.delete('/messages/:messageId', async (req, res) => {
    try {
        const userId = req.user.id;
        const messageId = Number(req.params.messageId);

        if (!messageId) {
            return res.status(400).json({
                success: false,
                message: 'ID tin nhắn không hợp lệ.'
            });
        }

        const [result] = await pool.query(
            `UPDATE project_messages
             SET deleted_at = NOW()
             WHERE id = ? AND sender_id = ? AND deleted_at IS NULL`,
            [messageId, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tin nhắn hoặc bạn không có quyền xóa.'
            });
        }

        return res.json({
            success: true,
            message: 'Đã xóa tin nhắn.'
        });
    } catch (err) {
        console.error('Lỗi xóa tin nhắn dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa tin nhắn.',
            error: err.message
        });
    }
});

module.exports = router;
