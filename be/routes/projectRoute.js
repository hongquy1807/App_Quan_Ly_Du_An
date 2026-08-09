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
const LEADER_ROLE_ID = 1;
const MEMBER_ROLE_ID = 3;
const INVITATION_STATUS = {
    pending: 'pending',
    accepted: 'accepted',
    declined: 'declined'
};

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

function normalizeDate(value) {
    if (!value) return null;
    const text = String(value).trim();
    if (!text) return null;

    const dateOnlyMatch = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (dateOnlyMatch) return text;

    const date = new Date(text);
    if (Number.isNaN(date.getTime())) return null;

    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase();
}

function isBcryptHash(value) {
    return typeof value === 'string' && /^\$2[aby]\$\d{2}\$/.test(value);
}

async function verifyPassword(enteredPassword, storedPassword) {
    if (typeof storedPassword !== 'string') return false;

    const legacyDemoPasswords = ['12345678', 'password', '123456', 'admin123', '123456789'];
    const isLegacyDemo = storedPassword.includes('fakehash') || storedPassword.includes('fake') || storedPassword.startsWith('$2y$10$fake');

    if (isLegacyDemo) {
        return legacyDemoPasswords.includes(enteredPassword);
    }

    if (isBcryptHash(storedPassword)) {
        try {
            return await bcrypt.compare(enteredPassword, storedPassword);
        } catch (err) {
            return false;
        }
    }

    return storedPassword === enteredPassword;
}

function mapProject(row) {
    return {
        id: row.id,
        name: row.name,
        description: row.description,
        owner_id: row.owner_id,
        owner_name: row.owner_name,
        status: row.status,
        start_date: row.start_date,
        end_date: row.end_date,
        project_role_id: row.project_role_id,
        role_name: row.role_name,
        color: getProjectColor(row.id),
        members: Number(row.members || 0),
        totalTasks: Number(row.total_tasks || 0),
        completedTasks: Number(row.completed_tasks || 0),
        incompleteTasks: Number(row.incomplete_tasks || 0),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapInvitation(row) {
    return {
        id: row.id,
        project_id: row.project_id,
        project_name: row.project_name,
        project_description: row.project_description,
        inviter_id: row.inviter_id,
        inviter_name: row.inviter_name,
        inviter_email: row.inviter_email,
        invitee_id: row.invitee_id,
        invitee_name: row.invitee_name,
        invitee_email: row.invitee_email,
        project_role_id: row.project_role_id,
        role_name: row.role_name,
        status: row.status,
        created_at: row.created_at,
        responded_at: row.responded_at,
        color: getProjectColor(row.project_id)
    };
}

async function getProjectById(projectId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                p.status, p.start_date, p.end_date, p.created_at, p.updated_at,
                pm.project_role_id, pr.name AS role_name,
                COUNT(DISTINCT all_pm.user_id) AS members,
                COUNT(DISTINCT t.id) AS total_tasks,
                COUNT(DISTINCT CASE WHEN t.status = 'done' THEN t.id END) AS completed_tasks,
                COUNT(DISTINCT CASE WHEN t.status <> 'done' OR t.status IS NULL THEN t.id END) AS incomplete_tasks
         FROM projects p
         INNER JOIN project_members pm
                 ON pm.project_id = p.id AND pm.user_id = ?
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         LEFT JOIN users owner ON owner.id = p.owner_id
         LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
         LEFT JOIN tasks t ON t.project_id = p.id
         WHERE p.id = ?
         GROUP BY p.id, p.name, p.description, p.owner_id, owner.name,
                  p.status, p.start_date, p.end_date, p.created_at, p.updated_at,
                  pm.project_role_id, pr.name
         LIMIT 1`,
        [userId, projectId]
    );

    return rows[0] ? mapProject(rows[0]) : null;
}

async function isProjectLeader(projectId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT p.id
         FROM projects p
         LEFT JOIN project_members pm
                ON pm.project_id = p.id AND pm.user_id = ?
         WHERE p.id = ?
           AND (p.owner_id = ? OR pm.project_role_id = ?)
         LIMIT 1`,
        [userId, projectId, userId, LEADER_ROLE_ID]
    );

    return rows.length > 0;
}

async function getUserPassword(userId, connection = pool) {
    const [rows] = await connection.query(
        'SELECT password FROM users WHERE id = ? LIMIT 1',
        [userId]
    );

    return rows[0]?.password || null;
}

router.use(requireAuth);

// GET /api/projects
// Danh sách dự án mà user đang sở hữu hoặc đang tham gia.
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const sort = req.query.sort === 'desc' ? 'DESC' : 'ASC';

        const [rows] = await pool.query(
            `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                    p.status, p.start_date, p.end_date, p.created_at, p.updated_at,
                    pm.project_role_id, pr.name AS role_name,
                    COUNT(DISTINCT all_pm.user_id) AS members,
                    COUNT(DISTINCT t.id) AS total_tasks,
                    COUNT(DISTINCT CASE WHEN t.status = 'done' THEN t.id END) AS completed_tasks,
                    COUNT(DISTINCT CASE WHEN t.status <> 'done' OR t.status IS NULL THEN t.id END) AS incomplete_tasks
             FROM projects p
             INNER JOIN project_members pm
                     ON pm.project_id = p.id AND pm.user_id = ?
             LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
             LEFT JOIN users owner ON owner.id = p.owner_id
             LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
             LEFT JOIN tasks t ON t.project_id = p.id
             GROUP BY p.id, p.name, p.description, p.owner_id, owner.name,
                      p.status, p.start_date, p.end_date, p.created_at, p.updated_at,
                      pm.project_role_id, pr.name
             ORDER BY p.name ${sort}`,
            [userId]
        );

        return res.json({
            success: true,
            data: rows.map(mapProject)
        });
    } catch (err) {
        console.error('Lỗi lấy danh sách dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy danh sách dự án.',
            error: err.message
        });
    }
});

// GET /api/projects/:id
// Chi tiết cơ bản của một dự án.
// GET /api/projects/invitations
// Lấy các lời mời tham gia dự án của user đang đăng nhập.
router.get('/invitations', async (req, res) => {
    try {
        const userId = req.user.id;
        const status = String(req.query.status || INVITATION_STATUS.pending).trim();

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
                    p.description AS project_description,
                    pi.inviter_id, inviter.name AS inviter_name,
                    inviter.email AS inviter_email,
                    pi.invitee_id, pi.invitee_email,
                    pi.project_role_id, pr.name AS role_name,
                    pi.status, pi.created_at, pi.responded_at
             FROM project_invitations pi
             INNER JOIN projects p ON p.id = pi.project_id
             INNER JOIN users inviter ON inviter.id = pi.inviter_id
             LEFT JOIN project_roles pr ON pr.id = pi.project_role_id
             INNER JOIN users invitee_user ON invitee_user.id = ?
             WHERE pi.status = ?
               AND (pi.invitee_id = ? OR LOWER(pi.invitee_email) = LOWER(invitee_user.email))
             ORDER BY pi.created_at DESC`,
            [userId, status, userId]
        );

        return res.json({
            success: true,
            data: rows.map(mapInvitation)
        });
    } catch (err) {
        console.error('Lỗi lấy lời mời tham gia dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy lời mời tham gia dự án.',
            error: err.message
        });
    }
});

// POST /api/projects/:id/invitations
// Trưởng nhóm gửi lời mời tham gia dự án qua email.
router.post('/:id/invitations', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const inviteeEmail = normalizeEmail(req.body.email || req.body.invitee_email);
        const projectRoleId = Number(req.body.project_role_id || MEMBER_ROLE_ID);

        if (!projectId) {
            return res.status(400).json({ success: false, message: 'ID dự án không hợp lệ.' });
        }

        if (!inviteeEmail) {
            return res.status(400).json({ success: false, message: 'Email người được mời không được để trống.' });
        }

        const canInvite = await isProjectLeader(projectId, userId);
        if (!canInvite) {
            return res.status(403).json({ success: false, message: 'Chỉ trưởng nhóm mới được gửi lời mời tham gia dự án.' });
        }

        const [[projectRows], [roleRows], [inviteeRows], [inviterRows]] = await Promise.all([
            pool.query('SELECT id, name FROM projects WHERE id = ? LIMIT 1', [projectId]),
            pool.query('SELECT id FROM project_roles WHERE id = ? LIMIT 1', [projectRoleId]),
            pool.query('SELECT id, email, name FROM users WHERE LOWER(email) = ? LIMIT 1', [inviteeEmail]),
            pool.query('SELECT id, email FROM users WHERE id = ? LIMIT 1', [userId])
        ]);

        if (projectRows.length === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy dự án.' });
        }

        if (roleRows.length === 0) {
            return res.status(400).json({ success: false, message: 'Vai trò dự án không hợp lệ.' });
        }

        const invitee = inviteeRows[0] || null;
        const inviter = inviterRows[0] || null;
        if ((invitee && invitee.id === userId) || (inviter && normalizeEmail(inviter.email) === inviteeEmail)) {
            return res.status(400).json({ success: false, message: 'Bạn không thể tự gửi lời mời cho chính mình.' });
        }

        if (invitee) {
            const [memberRows] = await pool.query(
                `SELECT id FROM project_members WHERE project_id = ? AND user_id = ? LIMIT 1`,
                [projectId, invitee.id]
            );
            if (memberRows.length > 0) {
                return res.status(409).json({ success: false, message: 'Người dùng này đã là thành viên của dự án.' });
            }
        }

        const [pendingRows] = await pool.query(
            `SELECT id
             FROM project_invitations
             WHERE project_id = ? AND LOWER(invitee_email) = ? AND status = ?
             LIMIT 1`,
            [projectId, inviteeEmail, INVITATION_STATUS.pending]
        );

        if (pendingRows.length > 0) {
            return res.status(409).json({ success: false, message: 'Lời mời cho email này đang chờ phản hồi.' });
        }

        const [result] = await pool.query(
            `INSERT INTO project_invitations
             (project_id, inviter_id, invitee_email, invitee_id, project_role_id, status)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [projectId, userId, inviteeEmail, invitee?.id || null, projectRoleId, INVITATION_STATUS.pending]
        );

        if (invitee) {
            await pool.query(
                `INSERT INTO notifications (user_id, type, content, data)
                 VALUES (?, ?, ?, ?)`,
                [
                    invitee.id,
                    'project_invitation',
                    `Bạn được mời tham gia dự án ${projectRows[0].name}.`,
                    JSON.stringify({ invitation_id: result.insertId, project_id: projectId })
                ]
            );
        }

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
                    p.description AS project_description,
                    pi.inviter_id, inviter.name AS inviter_name,
                    inviter.email AS inviter_email,
                    pi.invitee_id, pi.invitee_email,
                    pi.project_role_id, pr.name AS role_name,
                    pi.status, pi.created_at, pi.responded_at
             FROM project_invitations pi
             INNER JOIN projects p ON p.id = pi.project_id
             INNER JOIN users inviter ON inviter.id = pi.inviter_id
             LEFT JOIN project_roles pr ON pr.id = pi.project_role_id
             WHERE pi.id = ?
             LIMIT 1`,
            [result.insertId]
        );

        return res.status(201).json({
            success: true,
            message: 'Gửi lời mời tham gia dự án thành công.',
            data: mapInvitation(rows[0])
        });
    } catch (err) {
        console.error('Lỗi gửi lời mời tham gia dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể gửi lời mời tham gia dự án.',
            error: err.message
        });
    }
});

// GET /api/projects/:id/invitations/sent
// Trưởng nhóm xem các lời mời đã gửi của dự án.
router.get('/:id/invitations/sent', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const status = String(req.query.status || INVITATION_STATUS.pending).trim();

        if (!projectId) {
            return res.status(400).json({ success: false, message: 'ID dự án không hợp lệ.' });
        }

        const canViewInvitations = await isProjectLeader(projectId, userId);
        if (!canViewInvitations) {
            return res.status(403).json({ success: false, message: 'Chỉ trưởng nhóm mới được xem lời mời đã gửi.' });
        }

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
                    p.description AS project_description,
                    pi.inviter_id, inviter.name AS inviter_name,
                    inviter.email AS inviter_email,
                    pi.invitee_id, invitee.name AS invitee_name,
                    pi.invitee_email, pi.project_role_id, pr.name AS role_name,
                    pi.status, pi.created_at, pi.responded_at
             FROM project_invitations pi
             INNER JOIN projects p ON p.id = pi.project_id
             INNER JOIN users inviter ON inviter.id = pi.inviter_id
             LEFT JOIN users invitee ON invitee.id = pi.invitee_id
             LEFT JOIN project_roles pr ON pr.id = pi.project_role_id
             WHERE pi.project_id = ?
               AND (? = 'all' OR pi.status = ?)
             ORDER BY pi.created_at DESC`,
            [projectId, status, status]
        );

        return res.json({
            success: true,
            data: rows.map(mapInvitation)
        });
    } catch (err) {
        console.error('Lỗi lấy lời mời đã gửi:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy lời mời đã gửi.',
            error: err.message
        });
    }
});

// DELETE /api/projects/:id/invitations/:invitationId
// Trưởng nhóm thu hồi lời mời đang chờ phản hồi.
router.delete('/:id/invitations/:invitationId', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const invitationId = Number(req.params.invitationId);

        if (!projectId || !invitationId) {
            return res.status(400).json({ success: false, message: 'ID dự án hoặc ID lời mời không hợp lệ.' });
        }

        const canRevokeInvitation = await isProjectLeader(projectId, userId);
        if (!canRevokeInvitation) {
            return res.status(403).json({ success: false, message: 'Chỉ trưởng nhóm mới được thu hồi lời mời.' });
        }

        const [result] = await pool.query(
            `DELETE FROM project_invitations
             WHERE id = ? AND project_id = ? AND status = ?`,
            [invitationId, projectId, INVITATION_STATUS.pending]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời đang chờ phản hồi.' });
        }

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
                    p.description AS project_description,
                    pi.inviter_id, inviter.name AS inviter_name,
                    inviter.email AS inviter_email,
                    pi.invitee_id, invitee.name AS invitee_name,
                    pi.invitee_email, pi.project_role_id, pr.name AS role_name,
                    pi.status, pi.created_at, pi.responded_at
             FROM project_invitations pi
             INNER JOIN projects p ON p.id = pi.project_id
             INNER JOIN users inviter ON inviter.id = pi.inviter_id
             LEFT JOIN users invitee ON invitee.id = pi.invitee_id
             LEFT JOIN project_roles pr ON pr.id = pi.project_role_id
             WHERE pi.project_id = ? AND pi.status = ?
             ORDER BY pi.created_at DESC`,
            [projectId, INVITATION_STATUS.pending]
        );

        return res.json({
            success: true,
            message: 'Đã thu hồi lời mời.',
            data: {
                removed_invitation_id: invitationId,
                invitations: rows.map(mapInvitation)
            }
        });
    } catch (err) {
        console.error('Lỗi thu hồi lời mời:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể thu hồi lời mời.',
            error: err.message
        });
    }
});

// PATCH /api/projects/invitations/:invitationId/accept
// Chấp nhận lời mời và thêm user vào project_members.
router.patch('/invitations/:invitationId/accept', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const invitationId = Number(req.params.invitationId);

        if (!invitationId) {
            return res.status(400).json({ success: false, message: 'ID lời mời không hợp lệ.' });
        }

        await connection.beginTransaction();

        const [rows] = await connection.query(
            `SELECT pi.*, u.email AS current_email
             FROM project_invitations pi
             INNER JOIN users u ON u.id = ?
             WHERE pi.id = ?
               AND pi.status = ?
               AND (pi.invitee_id = ? OR LOWER(pi.invitee_email) = LOWER(u.email))
             LIMIT 1
             FOR UPDATE`,
            [userId, invitationId, INVITATION_STATUS.pending, userId]
        );

        const invitation = rows[0];
        if (!invitation) {
            await connection.rollback();
            return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời đang chờ phản hồi.' });
        }

        const [memberRows] = await connection.query(
            `SELECT id FROM project_members WHERE project_id = ? AND user_id = ? LIMIT 1`,
            [invitation.project_id, userId]
        );

        if (memberRows.length === 0) {
            await connection.query(
                `INSERT INTO project_members (project_id, user_id, project_role_id)
                 VALUES (?, ?, ?)`,
                [invitation.project_id, userId, invitation.project_role_id || MEMBER_ROLE_ID]
            );
        }

        await connection.query(
            `UPDATE project_invitations
             SET status = ?, invitee_id = ?, responded_at = NOW()
             WHERE id = ?`,
            [INVITATION_STATUS.accepted, userId, invitationId]
        );

        await connection.commit();

        return res.json({ success: true, message: 'Đã chấp nhận lời mời tham gia dự án.' });
    } catch (err) {
        await connection.rollback();
        console.error('Lỗi chấp nhận lời mời:', err);
        return res.status(500).json({ success: false, message: 'Không thể chấp nhận lời mời.', error: err.message });
    } finally {
        connection.release();
    }
});

// PATCH /api/projects/invitations/:invitationId/decline
// Từ chối lời mời tham gia dự án.
router.patch('/invitations/:invitationId/decline', async (req, res) => {
    try {
        const userId = req.user.id;
        const invitationId = Number(req.params.invitationId);

        if (!invitationId) {
            return res.status(400).json({ success: false, message: 'ID lời mời không hợp lệ.' });
        }

        const [result] = await pool.query(
            `UPDATE project_invitations pi
             INNER JOIN users u ON u.id = ?
             SET pi.status = ?, pi.invitee_id = COALESCE(pi.invitee_id, ?), pi.responded_at = NOW()
             WHERE pi.id = ?
               AND pi.status = ?
               AND (pi.invitee_id = ? OR LOWER(pi.invitee_email) = LOWER(u.email))`,
            [userId, INVITATION_STATUS.declined, userId, invitationId, INVITATION_STATUS.pending, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời đang chờ phản hồi.' });
        }

        return res.json({ success: true, message: 'Đã từ chối lời mời tham gia dự án.' });
    } catch (err) {
        console.error('Lỗi từ chối lời mời:', err);
        return res.status(500).json({ success: false, message: 'Không thể từ chối lời mời.', error: err.message });
    }
});
router.get('/:id', async (req, res) => {
    try {
        const project = await getProjectById(req.params.id, req.user.id);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án hoặc bạn không có quyền xem.'
            });
        }

        return res.json({
            success: true,
            data: project
        });
    } catch (err) {
        console.error('Lỗi lấy chi tiết dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy chi tiết dự án.',
            error: err.message
        });
    }
});

// POST /api/projects
// Tạo dự án mới. Người tạo tự động là trưởng nhóm.
router.post('/', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const name = String(req.body.name || '').trim();
        const description = String(req.body.description || '').trim() || null;
        const status = String(req.body.status || 'planning').trim();
        const startDate = normalizeDate(req.body.start_date) || normalizeDate(new Date());
        const endDate = normalizeDate(req.body.end_date || req.body.deadline);
        const memberEmails = Array.isArray(req.body.member_emails)
            ? req.body.member_emails
                .map((email) => String(email || '').trim().toLowerCase())
                .filter(Boolean)
            : [];

        if (!name) {
            connection.release();
            return res.status(400).json({
                success: false,
                message: 'Tên dự án không được để trống.'
            });
        }

        await connection.beginTransaction();

        const [projectResult] = await connection.query(
            `INSERT INTO projects (name, description, owner_id, status, start_date, end_date)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [name, description, userId, status, startDate, endDate]
        );

        const projectId = projectResult.insertId;
        await connection.query(
            `INSERT INTO project_members (project_id, user_id, project_role_id)
             VALUES (?, ?, ?)`,
            [projectId, userId, LEADER_ROLE_ID]
        );

        const uniqueEmails = [...new Set(memberEmails)];
        let invitedMembers = [];
        let missingMembers = [];

        if (uniqueEmails.length > 0) {
            const [users] = await connection.query(
                `SELECT id, email, name
                 FROM users
                 WHERE LOWER(email) IN (?)`,
                [uniqueEmails]
            );

            const foundEmails = new Set(users.map((user) => String(user.email).toLowerCase()));
            const invitees = users.filter((user) => Number(user.id) !== Number(userId));
            missingMembers = uniqueEmails.filter((email) => !foundEmails.has(email));
            invitedMembers = invitees.map((user) => ({
                id: user.id,
                email: user.email,
                name: user.name
            }));

            for (const user of invitees) {
                const [invitationResult] = await connection.query(
                    `INSERT INTO project_invitations
                     (project_id, inviter_id, invitee_email, invitee_id, project_role_id, status)
                     VALUES (?, ?, ?, ?, ?, ?)`,
                    [projectId, userId, normalizeEmail(user.email), user.id, MEMBER_ROLE_ID, INVITATION_STATUS.pending]
                );

                await connection.query(
                    `INSERT INTO notifications (user_id, type, content, data)
                     VALUES (?, ?, ?, ?)`,
                    [
                        user.id,
                        'project_invitation',
                        `Bạn được mời tham gia dự án ${name}.`,
                        JSON.stringify({ invitation_id: invitationResult.insertId, project_id: projectId })
                    ]
                );
            }
        }

        const project = await getProjectById(projectId, userId, connection);
        await connection.commit();

        return res.status(201).json({
            success: true,
            message: 'Tạo dự án thành công.',
            data: {
                project,
                invited_members: invitedMembers,
                missing_members: missingMembers
            }
        });
    } catch (err) {
        await connection.rollback();
        console.error('Lỗi tạo dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tạo dự án.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

// PATCH /api/projects/:id
// Chỉ trưởng nhóm mới được sửa thông tin dự án.
router.patch('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const canEdit = await isProjectLeader(projectId, userId);
        if (!canEdit) {
            return res.status(403).json({
                success: false,
                message: 'Chỉ trưởng nhóm mới được sửa dự án.'
            });
        }

        const fields = [];
        const values = [];

        if (Object.prototype.hasOwnProperty.call(req.body, 'name')) {
            const name = String(req.body.name || '').trim();
            if (!name) {
                return res.status(400).json({
                    success: false,
                    message: 'Tên dự án không được để trống.'
                });
            }
            fields.push('name = ?');
            values.push(name);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'description')) {
            const description = String(req.body.description || '').trim() || null;
            fields.push('description = ?');
            values.push(description);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'status')) {
            const status = String(req.body.status || '').trim() || 'planning';
            fields.push('status = ?');
            values.push(status);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'start_date')) {
            fields.push('start_date = ?');
            values.push(normalizeDate(req.body.start_date));
        }

        if (
            Object.prototype.hasOwnProperty.call(req.body, 'end_date') ||
            Object.prototype.hasOwnProperty.call(req.body, 'deadline')
        ) {
            fields.push('end_date = ?');
            values.push(normalizeDate(req.body.end_date || req.body.deadline));
        }

        if (fields.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Không có thông tin nào để cập nhật.'
            });
        }

        values.push(projectId);
        await pool.query(
            `UPDATE projects SET ${fields.join(', ')} WHERE id = ?`,
            values
        );

        const project = await getProjectById(projectId, userId);
        return res.json({
            success: true,
            message: 'Cập nhật dự án thành công.',
            data: project
        });
    } catch (err) {
        console.error('Lỗi cập nhật dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật dự án.',
            error: err.message
        });
    }
});

// DELETE /api/projects/:id
// Chỉ trưởng nhóm mới được xóa dự án và phải xác thực lại mật khẩu.
router.delete('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const password = String(req.body.password || req.body.current_password || '').trim();

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        if (!password) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập mật khẩu để xác nhận xóa dự án.'
            });
        }

        const canDelete = await isProjectLeader(projectId, userId);
        if (!canDelete) {
            return res.status(403).json({
                success: false,
                message: 'Chỉ trưởng nhóm mới được xóa dự án.'
            });
        }

        const storedPassword = await getUserPassword(userId);
        const passwordValid = await verifyPassword(password, storedPassword);
        if (!passwordValid) {
            return res.status(401).json({
                success: false,
                message: 'Mật khẩu xác thực không đúng.'
            });
        }

        const [result] = await pool.query(
            'DELETE FROM projects WHERE id = ?',
            [projectId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án.'
            });
        }

        return res.json({
            success: true,
            message: 'Xóa dự án thành công.'
        });
    } catch (err) {
        console.error('Lỗi xóa dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa dự án.',
            error: err.message
        });
    }
});

module.exports = router;
