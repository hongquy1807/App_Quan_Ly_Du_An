const express = require('express');
const fs = require('fs');
const mysql = require('mysql2/promise');
const path = require('path');
const jwt = require('jsonwebtoken');
const { sendPushToUser } = require('../services/pushService');

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
const TASK_STATUSES = ['todo', 'in_progress', 'review', 'done'];
const PROJECT_LEADER_ROLE_ID = 1;
const PROJECT_DEPUTY_ROLE_ID = 2;
const TASK_MANAGER_ROLE_IDS = [PROJECT_LEADER_ROLE_ID, PROJECT_DEPUTY_ROLE_ID];
const fileUploadDir = path.join(__dirname, '..', 'upload', 'file');

if (!fs.existsSync(fileUploadDir)) {
    fs.mkdirSync(fileUploadDir, { recursive: true });
}

function getBearerToken(req) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return null;
    return authHeader.slice(7).trim();
}

function sanitizeFileName(fileName) {
    const ext = path.extname(String(fileName || '')).toLowerCase();
    const baseName = path
        .basename(String(fileName || 'file'), ext)
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-zA-Z0-9_-]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_+|_+$/g, '')
        .slice(0, 60) || 'file';

    return `${baseName}${ext || ''}`;
}

function saveBase64File({ fileName, fileBase64 }) {
    const rawBase64 = String(fileBase64 || '').trim();
    if (!rawBase64) return null;

    const base64 = rawBase64.includes(',')
        ? rawBase64.split(',').pop()
        : rawBase64;
    const buffer = Buffer.from(base64, 'base64');
    const safeName = sanitizeFileName(fileName);
    const storedName = `${Date.now()}_${Math.round(Math.random() * 1e9)}_${safeName}`;
    const absolutePath = path.join(fileUploadDir, storedName);

    fs.writeFileSync(absolutePath, buffer);

    return {
        file_url: `/upload/file/${storedName}`,
        file_size: buffer.length
    };
}

function normalizeIdList(value) {
    if (value === undefined || value === null || value === '') return [];
    const values = Array.isArray(value) ? value : [value];
    return [...new Set(
        values
            .flatMap((item) => String(item).split(','))
            .map((item) => Number(String(item).trim()))
            .filter((item) => Number.isInteger(item) && item > 0)
    )];
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

function normalizeTaskStatus(value) {
    const status = String(value || '').trim();
    const normalized = status
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase();
    switch (status) {
        case 'todo':
            return 'todo';
        case 'in_progress':
            return 'in_progress';
        case 'review':
            return 'review';
        case 'done':
            return 'done';
        default:
            if (
                normalized === 'chua nhan' ||
                normalized === 'chua bat dau' ||
                normalized === 'todo'
            ) {
                return 'todo';
            }
            if (
                normalized === 'da nhan' ||
                normalized === 'da nhan nhiem vu' ||
                normalized === 'dang lam' ||
                normalized === 'in progress' ||
                normalized === 'in_progress'
            ) {
                return 'in_progress';
            }
            if (normalized === 'cho duyet' || normalized === 'review') {
                return 'review';
            }
            if (normalized === 'hoan thanh' || normalized === 'done') {
                return 'done';
            }
            return status;
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

function mapTask(row) {
    const assignees = parseTaskAssignees(row);
    const assigneeName = assignees.length > 0
        ? assignees.map((assignee) => assignee.name || assignee.email).filter(Boolean).join(', ')
        : row.assignee_name || 'Cả team';

    return {
        id: row.id,
        project_id: row.project_id,
        project_name: row.project_name,
        project_color: row.project_color || '#6366F1',
        title: row.title,
        description: row.description,
        assignee_id: row.assignee_id,
        assigneeId: row.assignee_id ? String(row.assignee_id) : '',
        assignee_ids: assignees.map((assignee) => assignee.id),
        assigneeIds: assignees.map((assignee) => String(assignee.id)),
        assignees,
        assignee: assigneeName || 'Cả team',
        assignee_email: row.assignee_email,
        due_date: row.due_date,
        dueDate: row.due_date,
        status_code: row.status,
        status: mapStatus(row.status),
        isCompleted: row.status === 'done',
        created_at: row.created_at,
        createdAt: row.created_at,
        updated_at: row.updated_at
    };
}

function parseTaskAssignees(row) {
    const ids = normalizeIdList(row.assignee_ids);
    const names = String(row.assignee_names || '').split('||');
    const emails = String(row.assignee_emails || '').split('||');

    return ids.map((id, index) => ({
        id,
        user_id: id,
        name: names[index] || '',
        email: emails[index] || ''
    }));
}
function mapSubtask(row) {
    return {
        id: row.id,
        task_id: row.task_id,
        title: row.title,
        is_completed: Boolean(row.is_completed),
        isCompleted: Boolean(row.is_completed),
        created_at: row.created_at,
        updated_at: row.updated_at
    };
}

function mapAttachment(row) {
    return {
        id: row.id,
        task_id: row.task_id,
        uploader_id: row.uploader_id,
        uploader_name: row.uploader_name,
        attachment_scope: row.attachment_scope || 'task',
        scope: row.attachment_scope || 'task',
        file_name: row.file_name,
        name: row.file_name,
        file_url: row.file_url,
        url: row.file_url,
        file_type: row.file_type,
        type: row.file_type,
        mime_type: row.mime_type,
        file_size: row.file_size,
        size: row.file_size,
        created_at: row.created_at
    };
}

function mapComment(row, currentUserId) {
    return {
        id: row.id,
        task_id: row.task_id,
        user_id: row.user_id,
        user: row.user_name,
        user_name: row.user_name,
        avatar: row.avatar,
        content: row.content,
        time: row.created_at,
        created_at: row.created_at,
        isMine: Number(row.user_id) === Number(currentUserId)
    };
}

async function tableExists(connection, tableName) {
    const [rows] = await connection.query('SHOW TABLES LIKE ?', [tableName]);
    return rows.length > 0;
}

async function columnExists(connection, tableName, columnName) {
    const [rows] = await connection.query(
        `SELECT COLUMN_NAME
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = ?
           AND COLUMN_NAME = ?
         LIMIT 1`,
        [tableName, columnName]
    );
    return rows.length > 0;
}

async function ensureTaskAttachmentScopeColumn(connection = pool) {
    if (!(await tableExists(connection, 'task_attachments'))) return false;
    if (await columnExists(connection, 'task_attachments', 'attachment_scope')) return true;
    await connection.query(
        `ALTER TABLE task_attachments
         ADD COLUMN attachment_scope ENUM('task','submission')
         COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'task'
         AFTER file_size`
    );
    return true;
}

async function ensureTaskCommentsTable(connection = pool) {
    await connection.query(
        `CREATE TABLE IF NOT EXISTS task_comments (
            id INT NOT NULL AUTO_INCREMENT,
            task_id INT NOT NULL,
            user_id INT NOT NULL,
            content TEXT COLLATE utf8mb4_unicode_ci NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY task_comments_task_idx (task_id),
            KEY task_comments_user_idx (user_id),
            CONSTRAINT task_comments_task_fk
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
            CONSTRAINT task_comments_user_fk
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
    );
}

async function ensureTaskAssigneesTable(connection = pool) {
    await connection.query(
        `CREATE TABLE IF NOT EXISTS task_assignees (
            task_id INT NOT NULL,
            user_id INT NOT NULL,
            assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (task_id, user_id),
            KEY task_assignees_user_idx (user_id),
            CONSTRAINT task_assignees_task_fk
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
            CONSTRAINT task_assignees_user_fk
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
    );
}

async function getAccessibleTask(taskId, userId, connection = pool) {
    await ensureTaskAssigneesTable(connection);
    const [rows] = await connection.query(
        `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                t.due_date, t.status, t.created_at, t.updated_at,
                pm.project_role_id,
                p.name AS project_name, assignee.name AS assignee_name,
                assignee.email AS assignee_email,
                GROUP_CONCAT(ta.user_id ORDER BY u.name ASC SEPARATOR ',') AS assignee_ids,
                GROUP_CONCAT(COALESCE(u.name, '') ORDER BY u.name ASC SEPARATOR '||') AS assignee_names,
                GROUP_CONCAT(COALESCE(u.email, '') ORDER BY u.name ASC SEPARATOR '||') AS assignee_emails
         FROM tasks t
         INNER JOIN projects p ON p.id = t.project_id
         INNER JOIN project_members pm
                 ON pm.project_id = t.project_id AND pm.user_id = ?
         LEFT JOIN users assignee ON assignee.id = t.assignee_id
         LEFT JOIN task_assignees ta ON ta.task_id = t.id
         LEFT JOIN users u ON u.id = ta.user_id
         WHERE t.id = ?
         GROUP BY t.id, t.project_id, t.title, t.description, t.assignee_id,
                  t.due_date, t.status, t.created_at, t.updated_at, pm.project_role_id,
                  p.name, assignee.name, assignee.email
         LIMIT 1`,
        [userId, taskId]
    );

    return rows[0] || null;
}

function canManageTask(task) {
    return TASK_MANAGER_ROLE_IDS.includes(Number(task?.project_role_id));
}

function canWorkOnTask(task, userId) {
    if (!task) return false;
    const assigneeIds = normalizeIdList(task.assignee_ids);
    if (assigneeIds.length > 0) return assigneeIds.includes(Number(userId));
    if (!task.assignee_id) return true;
    return Number(task.assignee_id) === Number(userId);
}

function taskWorkForbiddenResponse(res) {
    return res.status(403).json({
        success: false,
        message: 'Nhiá»‡m vá»¥ nĂ y khĂ´ng Ä‘Æ°á»£c giao cho báº¡n. Báº¡n chá»‰ cĂ³ quyá»n xem.'
    });
}

async function getSubtasks(taskId, connection = pool) {
    if (!(await tableExists(connection, 'task_subtasks'))) return [];
    const [rows] = await connection.query(
        `SELECT id, task_id, title, is_completed, created_at, updated_at
         FROM task_subtasks
         WHERE task_id = ?
         ORDER BY id ASC`,
        [taskId]
    );
    return rows.map(mapSubtask);
}

async function getAttachments(taskId, connection = pool) {
    if (!(await tableExists(connection, 'task_attachments'))) return [];
    await ensureTaskAttachmentScopeColumn(connection);
    const [rows] = await connection.query(
        `SELECT ta.id, ta.task_id, ta.uploader_id, uploader.name AS uploader_name,
                ta.file_name, ta.file_url, ta.file_type, ta.mime_type,
                ta.file_size, ta.attachment_scope, ta.created_at
         FROM task_attachments ta
         LEFT JOIN users uploader ON uploader.id = ta.uploader_id
         WHERE ta.task_id = ?
         ORDER BY ta.created_at DESC, ta.id DESC`,
        [taskId]
    );
    return rows.map(mapAttachment);
}

async function getComments(taskId, currentUserId, connection = pool) {
    await ensureTaskCommentsTable(connection);
    const [rows] = await connection.query(
        `SELECT tc.id, tc.task_id, tc.user_id, u.name AS user_name, u.avatar,
                tc.content, tc.created_at
         FROM task_comments tc
         INNER JOIN users u ON u.id = tc.user_id
         WHERE tc.task_id = ?
         ORDER BY tc.created_at DESC, tc.id DESC`,
        [taskId]
    );
    return rows.map((row) => mapComment(row, currentUserId));
}

async function getProjectMembers(projectId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT pm.user_id AS id, u.name, u.email, pm.project_role_id,
                pr.name AS role_name, pm.joined_at
         FROM project_members pm
         INNER JOIN users u ON u.id = pm.user_id
         LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
         WHERE pm.project_id = ?
         ORDER BY
            CASE pm.project_role_id
                WHEN 1 THEN 0
                WHEN 2 THEN 1
                ELSE 2
            END,
            u.name ASC`,
        [projectId]
    );

    return rows.map((row) => ({
        id: row.id,
        user_id: row.id,
        name: row.name,
        email: row.email,
        project_role_id: row.project_role_id,
        role_name: row.role_name,
        joined_at: row.joined_at
    }));
}

async function buildTaskDetail(taskId, userId, connection = pool) {
    const task = await getAccessibleTask(taskId, userId, connection);
    if (!task) return null;

    const [subtasks, attachments, comments, members] = await Promise.all([
        getSubtasks(taskId, connection),
        getAttachments(taskId, connection),
        getComments(taskId, userId, connection),
        getProjectMembers(task.project_id, connection)
    ]);

    return {
        task: {
            ...mapTask(task),
            subtasks,
            attachments,
            comments
        },
        project: {
            id: task.project_id,
            name: task.project_name,
            color: task.project_color || '#6366F1'
        },
        current_user_id: userId,
        can_update_work: canWorkOnTask(task, userId),
        can_manage_task: canManageTask(task),
        members,
        assignee_options: members,
        subtasks,
        attachments,
        comments
    };
}

router.use(requireAuth);

// GET /api/task-detail/:id
// Láº¥y chi tiáº¿t task cho task_detail_screen.dart.
router.get('/:id', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        if (!taskId) {
            return res.status(400).json({
                success: false,
                message: 'ID nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.'
            });
        }

        const data = await buildTaskDetail(taskId, req.user.id);
        if (!data) {
            return res.status(404).json({
                success: false,
                message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.'
            });
        }

        return res.json({ success: true, data });
    } catch (err) {
        console.error('Lá»—i láº¥y chi tiáº¿t nhiá»‡m vá»¥:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ láº¥y chi tiáº¿t nhiá»‡m vá»¥.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id
// Sua thong tin task chinh. Chi truong nhom hoac pho nhom duoc sua.
router.patch('/:id', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiem vu khong hop le.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Khong tim thay nhiem vu hoac ban khong co quyen xem.' });
        }

        if (!canManageTask(task)) {
            return res.status(403).json({ success: false, message: 'Chi truong nhom hoac pho nhom moi co quyen sua nhiem vu.' });
        }

        const fields = [];
        const values = [];
        let nextAssigneeIds = null;

        if (Object.prototype.hasOwnProperty.call(req.body, 'title')) {
            const title = String(req.body.title || '').trim();
            if (!title) {
                return res.status(400).json({ success: false, message: 'Ten nhiem vu khong duoc de trong.' });
            }
            fields.push('title = ?');
            values.push(title);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'description')) {
            fields.push('description = ?');
            values.push(String(req.body.description || '').trim() || null);
        }

        if (
            Object.prototype.hasOwnProperty.call(req.body, 'due_date') ||
            Object.prototype.hasOwnProperty.call(req.body, 'end_date')
        ) {
            fields.push('due_date = ?');
            values.push(normalizeDate(req.body.due_date || req.body.end_date));
        }

        if (
            Object.prototype.hasOwnProperty.call(req.body, 'assignee_ids') ||
            Object.prototype.hasOwnProperty.call(req.body, 'assignees') ||
            Object.prototype.hasOwnProperty.call(req.body, 'assignee_id') ||
            Object.prototype.hasOwnProperty.call(req.body, 'assigneeId')
        ) {
            const rawAssignees = Object.prototype.hasOwnProperty.call(req.body, 'assignee_ids')
                ? req.body.assignee_ids
                : Object.prototype.hasOwnProperty.call(req.body, 'assignees')
                    ? req.body.assignees
                    : (req.body.assignee_id || req.body.assigneeId);
            nextAssigneeIds = normalizeIdList(rawAssignees);

            if (nextAssigneeIds.length > 0) {
                const [memberRows] = await pool.query(
                    `SELECT user_id
                     FROM project_members
                     WHERE project_id = ? AND user_id IN (?)`,
                    [task.project_id, nextAssigneeIds]
                );
                const projectMemberIds = memberRows.map((row) => Number(row.user_id));
                const invalidAssigneeIds = nextAssigneeIds.filter((id) => !projectMemberIds.includes(id));

                if (invalidAssigneeIds.length > 0) {
                    return res.status(400).json({
                        success: false,
                        message: 'Nguoi nhan nhiem vu khong thuoc du an.',
                        invalid_assignee_ids: invalidAssigneeIds
                    });
                }
            }

            fields.push('assignee_id = ?');
            values.push(nextAssigneeIds[0] || null);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'status') || Object.prototype.hasOwnProperty.call(req.body, 'status_code')) {
            if (!canWorkOnTask(task, req.user.id)) {
                return taskWorkForbiddenResponse(res);
            }
            const status = normalizeTaskStatus(req.body.status || req.body.status_code);
            if (!TASK_STATUSES.includes(status)) {
                return res.status(400).json({ success: false, message: 'Trang thai nhiem vu khong hop le.' });
            }
            fields.push('status = ?');
            values.push(status);
        }

        if (fields.length === 0) {
            return res.status(400).json({ success: false, message: 'Khong co thong tin nao de cap nhat.' });
        }

        values.push(taskId);
        await pool.query(`UPDATE tasks SET ${fields.join(', ')} WHERE id = ?`, values);

        if (nextAssigneeIds !== null) {
            await ensureTaskAssigneesTable(pool);
            await pool.query('DELETE FROM task_assignees WHERE task_id = ?', [taskId]);
            if (nextAssigneeIds.length > 0) {
                await pool.query(
                    `INSERT IGNORE INTO task_assignees (task_id, user_id)
                     VALUES ?`,
                    [nextAssigneeIds.map((assigneeId) => [taskId, assigneeId])]
                );
            }
        }

        const data = await buildTaskDetail(taskId, req.user.id);
        return res.json({
            success: true,
            message: 'Cap nhat nhiem vu thanh cong.',
            data
        });
    } catch (err) {
        console.error('Loi cap nhat nhiem vu:', err);
        return res.status(500).json({
            success: false,
            message: 'Khong the cap nhat nhiem vu.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id/status
// Cáº­p nháº­t tráº¡ng thĂ¡i task: todo / in_progress / review / done.
router.patch('/:id/status', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const status = normalizeTaskStatus(req.body.status || req.body.status_code);

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.' });
        }

        if (!TASK_STATUSES.includes(status)) {
            return res.status(400).json({ success: false, message: 'Tráº¡ng thĂ¡i nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        await pool.query('UPDATE tasks SET status = ? WHERE id = ?', [status, taskId]);

        const notifyAssigneeIds = normalizeIdList(task.assignee_ids).filter((id) => id !== Number(req.user.id));
        if (status === 'done' && notifyAssigneeIds.length > 0) {
            const notificationContent = `Nhiệm vụ ${task.title} đã được đánh dấu hoàn thành.`;
            await pool.query(
                `INSERT INTO notifications (user_id, type, content, data, \`read\`)
                 VALUES ?`,
                [notifyAssigneeIds.map((assigneeId) => [
                    assigneeId,
                    'task',
                    notificationContent,
                    JSON.stringify({ task_id: taskId, project_id: task.project_id })
                    , 0
                ])]
            );
            notifyAssigneeIds.forEach((assigneeId) => {
                sendPushToUser(assigneeId, {
                    title: 'Cập nhật nhiệm vụ',
                    body: notificationContent,
                    data: { type: 'task', task_id: taskId, project_id: task.project_id }
                }).catch((err) => console.warn('Khong the gui push notification:', err.message));
            });
        }

        const data = await buildTaskDetail(taskId, req.user.id);
        return res.json({
            success: true,
            message: 'Cáº­p nháº­t tráº¡ng thĂ¡i nhiá»‡m vá»¥ thĂ nh cĂ´ng.',
            data
        });
    } catch (err) {
        console.error('Lá»—i cáº­p nháº­t tráº¡ng thĂ¡i nhiá»‡m vá»¥:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ cáº­p nháº­t tráº¡ng thĂ¡i nhiá»‡m vá»¥.',
            error: err.message
        });
    }
});

// DELETE /api/task-detail/:id
// Xoa task neu user co quyen xem task trong du an.
router.delete('/:id', async (req, res) => {
    try {
        const taskId = Number(req.params.id);

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiem vu khong hop le.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Khong tim thay nhiem vu hoac ban khong co quyen xoa.' });
        }

        if (!canManageTask(task)) {
            return res.status(403).json({ success: false, message: 'Chi truong nhom hoac pho nhom moi co quyen xoa nhiem vu.' });
        }

        const [result] = await pool.query('DELETE FROM tasks WHERE id = ?', [taskId]);
        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Khong tim thay nhiem vu.' });
        }

        return res.json({
            success: true,
            message: 'Xoa nhiem vu thanh cong.',
            data: { id: taskId, project_id: task.project_id }
        });
    } catch (err) {
        console.error('Loi xoa nhiem vu:', err);
        return res.status(500).json({
            success: false,
            message: 'Khong the xoa nhiem vu.',
            error: err.message
        });
    }
});

// POST /api/task-detail/:id/subtasks
// ThĂªm subtask má»›i.
router.post('/:id/subtasks', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const title = String(req.body.title || '').trim();

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.' });
        }

        if (!title) {
            return res.status(400).json({ success: false, message: 'TĂªn subtask khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        if (!(await tableExists(pool, 'task_subtasks'))) {
            return res.status(501).json({ success: false, message: 'Database chÆ°a cĂ³ báº£ng task_subtasks.' });
        }

        const [result] = await pool.query(
            'INSERT INTO task_subtasks (task_id, title, is_completed) VALUES (?, ?, 0)',
            [taskId, title]
        );

        const [rows] = await pool.query(
            `SELECT id, task_id, title, is_completed, created_at, updated_at
             FROM task_subtasks WHERE id = ? LIMIT 1`,
            [result.insertId]
        );

        return res.status(201).json({
            success: true,
            message: 'ThĂªm subtask thĂ nh cĂ´ng.',
            data: mapSubtask(rows[0])
        });
    } catch (err) {
        console.error('Lá»—i thĂªm subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ thĂªm subtask.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id/subtasks/:subtaskId
// Tick/bá» tick hoáº·c Ä‘á»•i tĂªn subtask.
router.patch('/:id/subtasks/:subtaskId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const subtaskId = Number(req.params.subtaskId);

        if (!taskId || !subtaskId) {
            return res.status(400).json({ success: false, message: 'ID subtask khĂ´ng há»£p lá»‡.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        const fields = [];
        const values = [];
        if (Object.prototype.hasOwnProperty.call(req.body, 'is_completed')) {
            fields.push('is_completed = ?');
            values.push(req.body.is_completed ? 1 : 0);
        }
        if (Object.prototype.hasOwnProperty.call(req.body, 'isCompleted')) {
            fields.push('is_completed = ?');
            values.push(req.body.isCompleted ? 1 : 0);
        }
        if (Object.prototype.hasOwnProperty.call(req.body, 'title')) {
            const title = String(req.body.title || '').trim();
            if (!title) {
                return res.status(400).json({ success: false, message: 'TĂªn subtask khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.' });
            }
            fields.push('title = ?');
            values.push(title);
        }

        if (fields.length === 0) {
            return res.status(400).json({ success: false, message: 'KhĂ´ng cĂ³ thĂ´ng tin nĂ o Ä‘á»ƒ cáº­p nháº­t.' });
        }

        values.push(subtaskId, taskId);

        const [result] = await pool.query(
            `UPDATE task_subtasks SET ${fields.join(', ')} WHERE id = ? AND task_id = ?`,
            values
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y subtask.' });
        }

        const [rows] = await pool.query(
            `SELECT id, task_id, title, is_completed, created_at, updated_at
             FROM task_subtasks WHERE id = ? LIMIT 1`,
            [subtaskId]
        );

        return res.json({
            success: true,
            message: 'Cáº­p nháº­t subtask thĂ nh cĂ´ng.',
            data: mapSubtask(rows[0])
        });
    } catch (err) {
        console.error('Lá»—i cáº­p nháº­t subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ cáº­p nháº­t subtask.',
            error: err.message
        });
    }
});

// DELETE /api/task-detail/:id/subtasks/:subtaskId
router.delete('/:id/subtasks/:subtaskId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const subtaskId = Number(req.params.subtaskId);

        if (!taskId || !subtaskId) {
            return res.status(400).json({ success: false, message: 'ID subtask khĂ´ng há»£p lá»‡.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        const [result] = await pool.query(
            'DELETE FROM task_subtasks WHERE id = ? AND task_id = ?',
            [subtaskId, taskId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y subtask.' });
        }

        return res.json({ success: true, message: 'XĂ³a subtask thĂ nh cĂ´ng.' });
    } catch (err) {
        console.error('Lá»—i xĂ³a subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ xĂ³a subtask.',
            error: err.message
        });
    }
});

// POST /api/task-detail/:id/attachments
// LÆ°u metadata file Ä‘Ă­nh kĂ¨m. Upload file nhá»‹ phĂ¢n nĂªn xá»­ lĂ½ á»Ÿ endpoint upload riĂªng.
router.post('/:id/attachments', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const fileName = String(req.body.file_name || req.body.name || '').trim();
        let fileUrl = String(req.body.file_url || req.body.url || '').trim();
        const fileType = String(req.body.file_type || req.body.type || 'document').trim();
        const mimeType = String(req.body.mime_type || req.body.mime || '').trim() || null;
        let fileSize = Number.isFinite(Number(req.body.file_size || req.body.size))
            ? Number(req.body.file_size || req.body.size)
            : null;
        const fileBase64 = req.body.file_base64 || req.body.base64;

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.' });
        }

        if (!fileName || (!fileUrl && !fileBase64)) {
            return res.status(400).json({ success: false, message: 'TĂªn file vĂ  Ä‘Æ°á»ng dáº«n file khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        if (!(await tableExists(pool, 'task_attachments'))) {
            return res.status(501).json({ success: false, message: 'Database chÆ°a cĂ³ báº£ng task_attachments.' });
        }
        await ensureTaskAttachmentScopeColumn(pool);

        if (fileBase64) {
            const savedFile = saveBase64File({ fileName, fileBase64 });
            if (savedFile) {
                fileUrl = savedFile.file_url;
                fileSize = savedFile.file_size;
            }
        }

        const normalizedType = ['image', 'video', 'document'].includes(fileType) ? fileType : 'document';
        const rawScope = String(req.body.attachment_scope || req.body.scope || 'submission').trim();
        const attachmentScope = rawScope === 'task' ? 'task' : 'submission';
        const [result] = await pool.query(
            `INSERT INTO task_attachments
                (task_id, uploader_id, file_name, file_url, file_type, mime_type, file_size, attachment_scope)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [taskId, req.user.id, fileName, fileUrl, normalizedType, mimeType, fileSize, attachmentScope]
        );

        const attachments = await getAttachments(taskId);
        return res.status(201).json({
            success: true,
            message: 'ThĂªm tĂ i liá»‡u Ä‘Ă­nh kĂ¨m thĂ nh cĂ´ng.',
            data: attachments.find((attachment) => Number(attachment.id) === Number(result.insertId)) || null
        });
    } catch (err) {
        console.error('Lá»—i thĂªm tĂ i liá»‡u Ä‘Ă­nh kĂ¨m:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ thĂªm tĂ i liá»‡u Ä‘Ă­nh kĂ¨m.',
            error: err.message
        });
    }
});

// DELETE /api/task-detail/:id/attachments/:attachmentId
router.delete('/:id/attachments/:attachmentId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const attachmentId = Number(req.params.attachmentId);

        if (!taskId || !attachmentId) {
            return res.status(400).json({ success: false, message: 'ID tĂ i liá»‡u khĂ´ng há»£p lá»‡.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n sá»­a.' });
        }

        if (!canWorkOnTask(task, req.user.id)) {
            return taskWorkForbiddenResponse(res);
        }

        const [result] = await pool.query(
            'DELETE FROM task_attachments WHERE id = ? AND task_id = ?',
            [attachmentId, taskId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y tĂ i liá»‡u Ä‘Ă­nh kĂ¨m.' });
        }

        return res.json({ success: true, message: 'XĂ³a tĂ i liá»‡u Ä‘Ă­nh kĂ¨m thĂ nh cĂ´ng.' });
    } catch (err) {
        console.error('Lá»—i xĂ³a tĂ i liá»‡u Ä‘Ă­nh kĂ¨m:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ xĂ³a tĂ i liá»‡u Ä‘Ă­nh kĂ¨m.',
            error: err.message
        });
    }
});

// POST /api/task-detail/:id/comments
// Hoáº¡t Ä‘á»™ng khi database cĂ³ báº£ng task_comments(id, task_id, user_id, content, created_at).
router.post('/:id/comments', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const content = String(req.body.content || '').trim();

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiá»‡m vá»¥ khĂ´ng há»£p lá»‡.' });
        }

        if (!content) {
            return res.status(400).json({ success: false, message: 'Ná»™i dung bĂ¬nh luáº­n khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n bĂ¬nh luáº­n.' });
        }

        await ensureTaskCommentsTable(pool);

        const [result] = await pool.query(
            'INSERT INTO task_comments (task_id, user_id, content) VALUES (?, ?, ?)',
            [taskId, req.user.id, content]
        );

        const [rows] = await pool.query(
            `SELECT tc.id, tc.task_id, tc.user_id, u.name AS user_name, u.avatar,
                    tc.content, tc.created_at
             FROM task_comments tc
             INNER JOIN users u ON u.id = tc.user_id
             WHERE tc.id = ?
             LIMIT 1`,
            [result.insertId]
        );

        return res.status(201).json({
            success: true,
            message: 'ThĂªm bĂ¬nh luáº­n thĂ nh cĂ´ng.',
            data: mapComment(rows[0], req.user.id)
        });
    } catch (err) {
        console.error('Lá»—i thĂªm bĂ¬nh luáº­n:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ thĂªm bĂ¬nh luáº­n.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id/comments/:commentId
// Chá»‰ ngÆ°á»i táº¡o bĂ¬nh luáº­n má»›i Ä‘Æ°á»£c sá»­a ná»™i dung bĂ¬nh luáº­n cá»§a mĂ¬nh.
router.patch('/:id/comments/:commentId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const commentId = Number(req.params.commentId);
        const content = String(req.body.content || '').trim();

        if (!taskId || !commentId) {
            return res.status(400).json({ success: false, message: 'ID bĂ¬nh luáº­n khĂ´ng há»£p lá»‡.' });
        }

        if (!content) {
            return res.status(400).json({ success: false, message: 'Ná»™i dung bĂ¬nh luáº­n khĂ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.' });
        }

        await ensureTaskCommentsTable(pool);

        const [result] = await pool.query(
            'UPDATE task_comments SET content = ? WHERE id = ? AND task_id = ? AND user_id = ?',
            [content, commentId, taskId, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y bĂ¬nh luáº­n cá»§a báº¡n.' });
        }

        const [rows] = await pool.query(
            `SELECT tc.id, tc.task_id, tc.user_id, u.name AS user_name, u.avatar,
                    tc.content, tc.created_at
             FROM task_comments tc
             INNER JOIN users u ON u.id = tc.user_id
             WHERE tc.id = ?
             LIMIT 1`,
            [commentId]
        );

        return res.json({
            success: true,
            message: 'Cáº­p nháº­t bĂ¬nh luáº­n thĂ nh cĂ´ng.',
            data: mapComment(rows[0], req.user.id)
        });
    } catch (err) {
        console.error('Lá»—i cáº­p nháº­t bĂ¬nh luáº­n:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ cáº­p nháº­t bĂ¬nh luáº­n.',
            error: err.message
        });
    }
});

// DELETE /api/task-detail/:id/comments/:commentId
// Chá»‰ ngÆ°á»i táº¡o bĂ¬nh luáº­n má»›i Ä‘Æ°á»£c xĂ³a bĂ¬nh luáº­n cá»§a mĂ¬nh.
router.delete('/:id/comments/:commentId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const commentId = Number(req.params.commentId);

        if (!taskId || !commentId) {
            return res.status(400).json({ success: false, message: 'ID bĂ¬nh luáº­n khĂ´ng há»£p lá»‡.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y nhiá»‡m vá»¥ hoáº·c báº¡n khĂ´ng cĂ³ quyá»n xem.' });
        }

        await ensureTaskCommentsTable(pool);

        const [result] = await pool.query(
            'DELETE FROM task_comments WHERE id = ? AND task_id = ? AND user_id = ?',
            [commentId, taskId, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'KhĂ´ng tĂ¬m tháº¥y bĂ¬nh luáº­n cá»§a báº¡n.' });
        }

        return res.json({ success: true, message: 'XĂ³a bĂ¬nh luáº­n thĂ nh cĂ´ng.' });
    } catch (err) {
        console.error('Lá»—i xĂ³a bĂ¬nh luáº­n:', err);
        return res.status(500).json({
            success: false,
            message: 'KhĂ´ng thá»ƒ xĂ³a bĂ¬nh luáº­n.',
            error: err.message
        });
    }
});

module.exports = router;

