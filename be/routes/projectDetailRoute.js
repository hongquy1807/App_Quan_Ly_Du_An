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
const PROJECT_LEADER_ROLE_ID = 1;
const PROJECT_DEPUTY_ROLE_ID = 2;
const PROJECT_MEMBER_ROLE_ID = 3;
const TASK_CREATOR_ROLE_IDS = [PROJECT_LEADER_ROLE_ID, PROJECT_DEPUTY_ROLE_ID];

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

function normalizeIdList(value) {
    const rawList = Array.isArray(value) ? value : value ? [value] : [];
    return [...new Set(
        rawList
            .map((item) => Number(item))
            .filter((item) => Number.isInteger(item) && item > 0)
    )];
}

function normalizeTextList(value) {
    const rawList = Array.isArray(value) ? value : value ? [value] : [];
    return rawList
        .map((item) => {
            if (typeof item === 'string') return item.trim();
            if (item && typeof item === 'object') return String(item.title || item.name || '').trim();
            return '';
        })
        .filter(Boolean);
}

function normalizeAttachments(value) {
    const rawList = Array.isArray(value) ? value : value ? [value] : [];
    return rawList
        .map((item) => {
            if (!item || typeof item !== 'object') return null;
            const fileName = String(item.file_name || item.name || '').trim();
            const fileUrl = String(item.file_url || item.url || item.path || '').trim();
            const fileType = String(item.file_type || item.type || 'document').trim();
            if (!fileName && !fileUrl) return null;
            return {
                file_name: fileName || fileUrl.split('/').pop() || 'Tá»‡p Ä‘Ă­nh kĂ¨m',
                file_url: fileUrl,
                file_type: ['image', 'video', 'document'].includes(fileType) ? fileType : 'document',
                mime_type: String(item.mime_type || item.mime || '').trim() || null,
                file_size: Number.isFinite(Number(item.file_size || item.size))
                    ? Number(item.file_size || item.size)
                    : null
            };
        })
        .filter(Boolean);
}

function requireAuth(req, res, next) {
    try {
        const token = getBearerToken(req);
        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Báº¡n chÆ°a Ä‘Äƒng nháº­p.'
            });
        }

        req.user = jwt.verify(token, JWT_SECRET);
        next();
    } catch (err) {
        return res.status(401).json({
            success: false,
            message: 'PhiĂªn Ä‘Äƒng nháº­p khĂ´ng há»£p lá»‡ hoáº·c Ä‘Ă£ háº¿t háº¡n.'
        });
    }
}

function mapStatus(status) {
    switch (status) {
        case 'done':
            return 'HoĂ n thĂ nh';
        case 'in_progress':
            return 'Äang lĂ m';
        case 'review':
            return 'Chá» duyá»‡t';
        case 'todo':
        default:
            return 'ChÆ°a báº¯t Ä‘áº§u';
    }
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
        created_at: row.created_at,
        updated_at: row.updated_at,
        project_role_id: row.project_role_id,
        role_name: row.role_name,
        color: getProjectColor(row.id)
    };
}

function mapMember(row) {
    return {
        id: row.user_id,
        name: row.name,
        email: row.email,
        avatar: row.avatar,
        project_role_id: row.project_role_id,
        role: row.role_name || 'ThĂ nh viĂªn',
        joined_at: row.joined_at
    };
}

function mapProjectInvitation(row) {
    return {
        id: row.id,
        project_id: row.project_id,
        project_name: row.project_name,
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
        responded_at: row.responded_at
    };
}

function mapSubtask(row) {
    return {
        id: row.id,
        task_id: row.task_id,
        title: row.title,
        is_completed: Boolean(row.is_completed),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapAttachment(row) {
    return {
        id: row.id,
        task_id: row.task_id,
        uploader_id: row.uploader_id,
        file_name: row.file_name,
        file_url: row.file_url,
        file_type: row.file_type,
        mime_type: row.mime_type,
        file_size: row.file_size,
        created_at: row.created_at
    };
}

function mapTask(row, subtasksByTask = {}, attachmentsByTask = {}) {
    const isCompleted = row.status === 'done';
    return {
        id: row.id,
        project_id: row.project_id,
        title: row.title,
        description: row.description,
        assignee_id: row.assignee_id,
        assigneeId: row.assignee_id ? String(row.assignee_id) : '',
        assignee: row.assignee_name || 'Cáº£ team',
        assignee_email: row.assignee_email,
        start_date: row.start_date,
        startDate: row.start_date,
        due_date: row.due_date,
        dueDate: row.due_date,
        status_code: row.status,
        status: mapStatus(row.status),
        isCompleted,
        subtasks: subtasksByTask[row.id] || [],
        attachments: attachmentsByTask[row.id] || [],
        created_at: row.created_at,
        createdAt: row.created_at,
        updated_at: row.updated_at
    };
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

async function ensureTaskStartDateColumn(connection) {
    if (await columnExists(connection, 'tasks', 'start_date')) return;
    await connection.query(
        'ALTER TABLE tasks ADD COLUMN start_date DATE NULL AFTER assignee_id'
    );
}

async function getProject(projectId, userId) {
    const [rows] = await pool.query(
        `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                p.status, p.start_date, p.end_date, p.created_at, p.updated_at,
                pm.project_role_id, pr.name AS role_name
         FROM projects p
         LEFT JOIN project_members pm
                ON pm.project_id = p.id AND pm.user_id = ?
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         LEFT JOIN users owner ON owner.id = p.owner_id
         WHERE p.id = ?
           AND (p.owner_id = ? OR pm.user_id = ?)
         LIMIT 1`,
        [userId, projectId, userId, userId]
    );

    return rows[0] || null;
}

async function getMembers(projectId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT pm.user_id, u.name, u.email, u.avatar,
                pm.project_role_id, pr.name AS role_name, pm.joined_at
         FROM project_members pm
         INNER JOIN users u ON u.id = pm.user_id
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         WHERE pm.project_id = ?
         ORDER BY
            CASE pm.project_role_id
                WHEN 1 THEN 1
                WHEN 2 THEN 2
                ELSE 3
            END,
            u.name ASC`,
        [projectId]
    );

    return rows.map(mapMember);
}

async function getProjectMemberIds(projectId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT user_id FROM project_members WHERE project_id = ?`,
        [projectId]
    );

    return rows.map((row) => Number(row.user_id));
}

function canManageProjectMembers(project, userId) {
    return Number(project.owner_id) === Number(userId) ||
        Number(project.project_role_id) === PROJECT_LEADER_ROLE_ID;
}

async function getProjectMember(projectId, memberId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT pm.user_id, u.name, u.email, u.avatar,
                pm.project_role_id, pr.name AS role_name, pm.joined_at
         FROM project_members pm
         INNER JOIN users u ON u.id = pm.user_id
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         WHERE pm.project_id = ? AND pm.user_id = ?
         LIMIT 1`,
        [projectId, memberId]
    );

    return rows[0] || null;
}

function normalizeProjectMemberRoleId(body) {
    const action = String(body.action || '').trim().toLowerCase();
    if (['promote', 'deputy', 'make_deputy'].includes(action)) {
        return PROJECT_DEPUTY_ROLE_ID;
    }
    if (['demote', 'member', 'make_member'].includes(action)) {
        return PROJECT_MEMBER_ROLE_ID;
    }

    const roleId = Number(body.project_role_id || body.role_id);
    if (roleId === PROJECT_DEPUTY_ROLE_ID || roleId === PROJECT_MEMBER_ROLE_ID) {
        return roleId;
    }

    return null;
}

async function getSubtasksByTaskIds(taskIds, connection = pool) {
    if (taskIds.length === 0 || !(await tableExists(connection, 'task_subtasks'))) {
        return {};
    }

    const [rows] = await connection.query(
        `SELECT id, task_id, title, is_completed, created_at, updated_at
         FROM task_subtasks
         WHERE task_id IN (?)
         ORDER BY id ASC`,
        [taskIds]
    );

    return rows.reduce((grouped, row) => {
        grouped[row.task_id] = grouped[row.task_id] || [];
        grouped[row.task_id].push(mapSubtask(row));
        return grouped;
    }, {});
}

async function getAttachmentsByTaskIds(taskIds, connection = pool) {
    if (taskIds.length === 0 || !(await tableExists(connection, 'task_attachments'))) {
        return {};
    }

    const [rows] = await connection.query(
        `SELECT id, task_id, uploader_id, file_name, file_url, file_type,
                mime_type, file_size, created_at
         FROM task_attachments
         WHERE task_id IN (?)
         ORDER BY id ASC`,
        [taskIds]
    );

    return rows.reduce((grouped, row) => {
        grouped[row.task_id] = grouped[row.task_id] || [];
        grouped[row.task_id].push(mapAttachment(row));
        return grouped;
    }, {});
}

async function getTasks(projectId) {
    await ensureTaskStartDateColumn(pool);
    const [rows] = await pool.query(
        `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                assignee.name AS assignee_name, assignee.email AS assignee_email,
                t.start_date, t.due_date, t.status, t.created_at, t.updated_at
         FROM tasks t
         LEFT JOIN users assignee ON assignee.id = t.assignee_id
         WHERE t.project_id = ?
         ORDER BY
            CASE WHEN t.status = 'done' THEN 1 ELSE 0 END,
            CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END,
            t.due_date ASC,
            t.created_at DESC`,
        [projectId]
    );

    const taskIds = rows.map((row) => row.id);
    const [subtasksByTask, attachmentsByTask] = await Promise.all([
        getSubtasksByTaskIds(taskIds),
        getAttachmentsByTaskIds(taskIds)
    ]);

    return rows.map((row) => mapTask(row, subtasksByTask, attachmentsByTask));
}

function buildStats(tasks, members) {
    const totalTasks = tasks.length;
    const completedTasks = tasks.filter((task) => task.isCompleted).length;
    return {
        total_tasks: totalTasks,
        completed_tasks: completedTasks,
        incomplete_tasks: totalTasks - completedTasks,
        in_progress_tasks: tasks.filter((task) => task.status_code === 'in_progress').length,
        todo_tasks: tasks.filter((task) => task.status_code === 'todo').length,
        member_count: members.length
    };
}

async function insertSubtasks(connection, taskIds, subtaskTitles) {
    if (taskIds.length === 0 || subtaskTitles.length === 0) return false;
    if (!(await tableExists(connection, 'task_subtasks'))) return false;

    const values = [];
    for (const taskId of taskIds) {
        for (const title of subtaskTitles) {
            values.push([taskId, title, 0]);
        }
    }

    await connection.query(
        `INSERT INTO task_subtasks (task_id, title, is_completed)
         VALUES ?`,
        [values]
    );
    return true;
}

async function insertAttachments(connection, taskIds, attachments, uploaderId) {
    if (taskIds.length === 0 || attachments.length === 0) return false;
    if (!(await tableExists(connection, 'task_attachments'))) return false;

    const values = [];
    for (const taskId of taskIds) {
        for (const attachment of attachments) {
            values.push([
                taskId,
                uploaderId,
                attachment.file_name,
                attachment.file_url,
                attachment.file_type,
                attachment.mime_type,
                attachment.file_size
            ]);
        }
    }

    await connection.query(
        `INSERT INTO task_attachments
            (task_id, uploader_id, file_name, file_url, file_type, mime_type, file_size)
         VALUES ?`,
        [values]
    );
    return true;
}

router.use(requireAuth);

// GET /api/project-detail/:id
// Láº¥y chi tiáº¿t dá»± Ă¡n cho project_detail_screen.dart.
router.get('/:id', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        const [members, tasks] = await Promise.all([
            getMembers(projectId),
            getTasks(projectId)
        ]);

        return res.json({
            success: true,
            data: {
                project: mapProject(project),
                current_user_id: userId,
                members,
                assignee_options: members,
                tasks,
                stats: buildStats(tasks, members)
            }
        });
    } catch (err) {
        console.error('Lá»—i láº¥y chi tiáº¿t dá»± Ă¡n:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ láº¥y chi tiáº¿t dá»± Ă¡n.',
            error: err.message
        });
    }
});

// GET /api/project-detail/:id/task-options
// Dá»¯ liá»‡u cho mĂ n táº¡o nhiá»‡m vá»¥: tráº£ toĂ n bá»™ thĂ nh viĂªn dá»± Ă¡n, gá»“m trÆ°á»Ÿng nhĂ³m/phĂ³ nhĂ³m/thĂ nh viĂªn.
router.get('/:id/task-options', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        const members = await getMembers(projectId);
        return res.json({
            success: true,
            data: {
                project: mapProject(project),
                members,
                assignee_options: members
            }
        });
    } catch (err) {
        console.error('Lá»—i láº¥y dá»¯ liá»‡u táº¡o nhiá»‡m vá»¥:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ láº¥y dá»¯ liá»‡u táº¡o nhiá»‡m vá»¥.',
            error: err.message
        });
    }
});

// POST /api/project-detail/:id/tasks
// Táº¡o nhiá»‡m vá»¥. Náº¿u chá»n nhiá»u ngÆ°á»i nháº­n, há»‡ thá»‘ng táº¡o má»™t task cho má»—i ngÆ°á»i.
// PATCH /api/project-detail/:id/members/:memberId/role
// Chá»‰ trÆ°á»Ÿng nhĂ³m/chá»§ dá»± Ă¡n Ä‘Æ°á»£c thÄƒng thĂ nh nhĂ³m phĂ³ hoáº·c giĂ¡ng vá» thĂ nh viĂªn.
// GET /api/project-detail/:id/invitations/sent
// TrÆ°á»Ÿng nhĂ³m/chá»§ dá»± Ă¡n xem danh sĂ¡ch lá»i má»i Ä‘Ă£ gá»­i cá»§a dá»± Ă¡n.
router.get('/:id/invitations/sent', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const status = String(req.query.status || 'pending').trim();

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        if (!canManageProjectMembers(project, userId)) {
            return res.status(403).json({
                success: false,
                message: 'Chá»‰ trÆ°á»Ÿng nhĂ³m má»›i Ä‘Æ°á»£c xem lá»i má»i Ä‘Ă£ gá»­i.'
            });
        }

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
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
            data: rows.map(mapProjectInvitation)
        });
    } catch (err) {
        console.error('Lá»—i láº¥y lá»i má»i Ä‘Ă£ gá»­i:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ láº¥y lá»i má»i Ä‘Ă£ gá»­i.',
            error: err.message
        });
    }
});

// DELETE /api/project-detail/:id/invitations/:invitationId
// TrÆ°á»Ÿng nhĂ³m/chá»§ dá»± Ă¡n thu há»“i lá»i má»i Ä‘ang chá» pháº£n há»“i.
router.delete('/:id/invitations/:invitationId', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const invitationId = Number(req.params.invitationId);

        if (!projectId || !invitationId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n hoáº·c ID lá»i má»i khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        if (!canManageProjectMembers(project, userId)) {
            return res.status(403).json({
                success: false,
                message: 'Chá»‰ trÆ°á»Ÿng nhĂ³m má»›i Ä‘Æ°á»£c thu há»“i lá»i má»i.'
            });
        }

        const [result] = await pool.query(
            `DELETE FROM project_invitations
             WHERE id = ? AND project_id = ? AND status = 'pending'`,
            [invitationId, projectId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y lá»i má»i Ä‘ang chá» pháº£n há»“i.'
            });
        }

        const [rows] = await pool.query(
            `SELECT pi.id, pi.project_id, p.name AS project_name,
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
             WHERE pi.project_id = ? AND pi.status = 'pending'
             ORDER BY pi.created_at DESC`,
            [projectId]
        );

        return res.json({
            success: true,
            message: 'ÄĂ£ thu há»“i lá»i má»i.',
            data: {
                removed_invitation_id: invitationId,
                invitations: rows.map(mapProjectInvitation)
            }
        });
    } catch (err) {
        console.error('Lá»—i thu há»“i lá»i má»i:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ thu há»“i lá»i má»i.',
            error: err.message
        });
    }
});

router.patch('/:id/members/:memberId/role', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const memberId = Number(req.params.memberId);
        const targetRoleId = normalizeProjectMemberRoleId(req.body || {});

        if (!projectId || !memberId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n hoáº·c ID thĂ nh viĂªn khĂ´ng há»£p lá»‡.'
            });
        }

        if (!targetRoleId) {
            return res.status(400).json({
                success: false,
                message: 'Vai trĂ² thĂ nh viĂªn khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        if (!canManageProjectMembers(project, userId)) {
            return res.status(403).json({
                success: false,
                message: 'Chá»‰ trÆ°á»Ÿng nhĂ³m má»›i Ä‘Æ°á»£c quáº£n lĂ½ thĂ nh viĂªn.'
            });
        }

        const member = await getProjectMember(projectId, memberId);
        if (!member) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y thĂ nh viĂªn trong dá»± Ă¡n.'
            });
        }

        if (Number(member.project_role_id) === PROJECT_LEADER_ROLE_ID) {
            return res.status(400).json({
                success: false,
                message: 'KhĂ´ng thá»ƒ thay Ä‘á»•i vai trĂ² cá»§a trÆ°á»Ÿng nhĂ³m.'
            });
        }

        await pool.query(
            `UPDATE project_members
             SET project_role_id = ?
             WHERE project_id = ? AND user_id = ?`,
            [targetRoleId, projectId, memberId]
        );

        const updatedMember = await getProjectMember(projectId, memberId);
        const members = await getMembers(projectId);

        return res.json({
            success: true,
            message: targetRoleId === PROJECT_DEPUTY_ROLE_ID
                ? 'ÄĂ£ thÄƒng thĂ nh nhĂ³m phĂ³.'
                : 'ÄĂ£ giĂ¡ng chá»©c thĂ nh viĂªn.',
            data: {
                member: mapMember(updatedMember),
                members
            }
        });
    } catch (err) {
        console.error('Lá»—i cáº­p nháº­t vai trĂ² thĂ nh viĂªn:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ cáº­p nháº­t vai trĂ² thĂ nh viĂªn.',
            error: err.message
        });
    }
});

// DELETE /api/project-detail/:id/members/:memberId
// Chá»‰ trÆ°á»Ÿng nhĂ³m/chá»§ dá»± Ă¡n Ä‘Æ°á»£c loáº¡i thĂ nh viĂªn khá»i dá»± Ă¡n.
router.delete('/:id/members/:memberId', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const memberId = Number(req.params.memberId);

        if (!projectId || !memberId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n hoáº·c ID thĂ nh viĂªn khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        if (!canManageProjectMembers(project, userId)) {
            return res.status(403).json({
                success: false,
                message: 'Chá»‰ trÆ°á»Ÿng nhĂ³m má»›i Ä‘Æ°á»£c quáº£n lĂ½ thĂ nh viĂªn.'
            });
        }

        if (Number(memberId) === Number(userId)) {
            return res.status(400).json({
                success: false,
                message: 'Báº¡n khĂ´ng thá»ƒ tá»± loáº¡i mĂ¬nh khá»i dá»± Ă¡n.'
            });
        }

        const member = await getProjectMember(projectId, memberId);
        if (!member) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y thĂ nh viĂªn trong dá»± Ă¡n.'
            });
        }

        if (Number(member.project_role_id) === PROJECT_LEADER_ROLE_ID) {
            return res.status(400).json({
                success: false,
                message: 'KhĂ´ng thá»ƒ loáº¡i trÆ°á»Ÿng nhĂ³m khá»i dá»± Ă¡n.'
            });
        }

        await pool.query(
            `DELETE FROM project_members
             WHERE project_id = ? AND user_id = ?`,
            [projectId, memberId]
        );

        const members = await getMembers(projectId);
        return res.json({
            success: true,
            message: 'ÄĂ£ loáº¡i thĂ nh viĂªn khá»i dá»± Ă¡n.',
            data: {
                removed_member_id: memberId,
                members
            }
        });
    } catch (err) {
        console.error('Lá»—i loáº¡i thĂ nh viĂªn khá»i dá»± Ă¡n:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ loáº¡i thĂ nh viĂªn khá»i dá»± Ă¡n.',
            error: err.message
        });
    }
});

router.post('/:id/tasks', async (req, res) => {
    const connection = await pool.getConnection();
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);
        const title = String(req.body.title || req.body.name || '').trim();
        const description = String(req.body.description || '').trim() || null;
        const startDate = normalizeDate(req.body.start_date || req.body.startDate);
        const dueDate = normalizeDate(req.body.due_date || req.body.end_date || req.body.deadline);
        const assigneeIds = normalizeIdList(req.body.assignee_ids || req.body.assignees || req.body.assignee_id);
        const subtaskTitles = normalizeTextList(req.body.subtasks || req.body.task_subtasks);
        const attachments = normalizeAttachments(req.body.attachments || req.body.files);
        const status = String(req.body.status || 'todo').trim();

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dá»± Ă¡n khĂ´ng há»£p lá»‡.'
            });
        }

        if (!title) {
            return res.status(400).json({
                success: false,
                message: 'TĂªn nhiá»‡m vá»¥ khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.'
            });
        }

        const allowedStatuses = ['todo', 'in_progress', 'review', 'done'];
        if (!allowedStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Tráº¡ng thĂ¡i nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.'
            });
        }

        const project = await getProject(projectId, userId);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y dá»± Ă¡n hoáº·c báº¡n khĂ´ng cĂ³ quyá»n táº¡o nhiá»‡m vá»¥.'
            });
        }

        const canCreateTask =
            Number(project.owner_id) === Number(userId) ||
            TASK_CREATOR_ROLE_IDS.includes(Number(project.project_role_id));
        if (!canCreateTask) {
            return res.status(403).json({
                success: false,
                message: 'Chá»‰ trÆ°á»Ÿng nhĂ³m hoáº·c phĂ³ nhĂ³m má»›i Ä‘Æ°á»£c táº¡o nhiá»‡m vá»¥.'
            });
        }

        await ensureTaskStartDateColumn(connection);
        await connection.beginTransaction();

        const projectMemberIds = await getProjectMemberIds(projectId, connection);
        const invalidAssigneeIds = assigneeIds.filter((id) => !projectMemberIds.includes(id));
        if (invalidAssigneeIds.length > 0) {
            await connection.rollback();
            return res.status(400).json({
                success: false,
                message: 'NgÆ°á»i nháº­n nhiá»‡m vá»¥ pháº£i lĂ  thĂ nh viĂªn cá»§a dá»± Ă¡n.',
                invalid_assignee_ids: invalidAssigneeIds
            });
        }

        const taskAssignees = assigneeIds.length > 0 ? assigneeIds : [null];
        const createdTaskIds = [];

        for (const assigneeId of taskAssignees) {
            const [result] = await connection.query(
                `INSERT INTO tasks (project_id, title, description, assignee_id, start_date, due_date, status)
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [projectId, title, description, assigneeId, startDate, dueDate, status]
            );
            createdTaskIds.push(result.insertId);

            if (assigneeId) {
                await connection.query(
                    `INSERT INTO notifications (user_id, type, content, data, \`read\`)
                     VALUES (?, 'task', ?, ?, 0)`,
                    [
                        assigneeId,
                        `Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: ${title}`,
                        JSON.stringify({ project_id: projectId, task_id: result.insertId })
                    ]
                );
            }
        }

        const subtasksSaved = await insertSubtasks(connection, createdTaskIds, subtaskTitles);
        const attachmentsSaved = await insertAttachments(connection, createdTaskIds, attachments, userId);

        await connection.commit();

        const [rows] = await connection.query(
            `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                    assignee.name AS assignee_name, assignee.email AS assignee_email,
                    t.start_date, t.due_date, t.status, t.created_at, t.updated_at
             FROM tasks t
             LEFT JOIN users assignee ON assignee.id = t.assignee_id
             WHERE t.id IN (?)
             ORDER BY t.id ASC`,
            [createdTaskIds]
        );

        const [subtasksByTask, attachmentsByTask] = await Promise.all([
            getSubtasksByTaskIds(createdTaskIds, connection),
            getAttachmentsByTaskIds(createdTaskIds, connection)
        ]);

        return res.status(201).json({
            success: true,
            message: 'Táº¡o nhiá»‡m vá»¥ thĂ nh cĂ´ng.',
            data: {
                tasks: rows.map((row) => mapTask(row, subtasksByTask, attachmentsByTask)),
                saved: {
                    subtasks: subtasksSaved,
                    attachments: attachmentsSaved
                },
                ignored_fields: {
                    attachments: attachments.length > 0 && !attachmentsSaved
                        ? 'Database hiá»‡n chÆ°a cĂ³ báº£ng task_attachments hoáº·c chÆ°a nháº­n Ä‘Æ°á»£c file_url.'
                        : null
                }
            }
        });
    } catch (err) {
        try {
            await connection.rollback();
        } catch (_) {}
        console.error('Lá»—i táº¡o nhiá»‡m vá»¥:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ táº¡o nhiá»‡m vá»¥.',
            error: err.message
        });
    } finally {
        connection.release();
    }
});

module.exports = router;
