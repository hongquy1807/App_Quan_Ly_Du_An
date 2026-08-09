const express = require('express');
const fs = require('fs');
const mysql = require('mysql2/promise');
const path = require('path');
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

function normalizeTaskStatus(value) {
    const status = String(value || '').trim();
    switch (status) {
        case 'Chưa nhận':
        case 'Chưa bắt đầu':
        case 'todo':
            return 'todo';
        case 'Đã nhận nhiệm vụ':
        case 'Đang làm':
        case 'in_progress':
            return 'in_progress';
        case 'Chờ duyệt':
        case 'review':
            return 'review';
        case 'Hoàn thành':
        case 'done':
            return 'done';
        default:
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
            return 'Hoàn thành';
        case 'in_progress':
            return 'Đang làm';
        case 'review':
            return 'Chờ duyệt';
        case 'todo':
        default:
            return 'Chưa bắt đầu';
    }
}

function mapTask(row) {
    return {
        id: row.id,
        project_id: row.project_id,
        project_name: row.project_name,
        project_color: row.project_color || '#6366F1',
        title: row.title,
        description: row.description,
        assignee_id: row.assignee_id,
        assigneeId: row.assignee_id ? String(row.assignee_id) : '',
        assignee: row.assignee_name || 'Cả team',
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

async function getAccessibleTask(taskId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT t.id, t.project_id, t.title, t.description, t.assignee_id,
                t.due_date, t.status, t.created_at, t.updated_at,
                pm.project_role_id,
                p.name AS project_name, assignee.name AS assignee_name,
                assignee.email AS assignee_email
         FROM tasks t
         INNER JOIN projects p ON p.id = t.project_id
         INNER JOIN project_members pm
                 ON pm.project_id = t.project_id AND pm.user_id = ?
         LEFT JOIN users assignee ON assignee.id = t.assignee_id
         WHERE t.id = ?
         LIMIT 1`,
        [userId, taskId]
    );

    return rows[0] || null;
}

function canManageTask(task) {
    return TASK_MANAGER_ROLE_IDS.includes(Number(task?.project_role_id));
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
    const [rows] = await connection.query(
        `SELECT ta.id, ta.task_id, ta.uploader_id, uploader.name AS uploader_name,
                ta.file_name, ta.file_url, ta.file_type, ta.mime_type,
                ta.file_size, ta.created_at
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

async function buildTaskDetail(taskId, userId, connection = pool) {
    const task = await getAccessibleTask(taskId, userId, connection);
    if (!task) return null;

    const [subtasks, attachments, comments] = await Promise.all([
        getSubtasks(taskId, connection),
        getAttachments(taskId, connection),
        getComments(taskId, userId, connection)
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
        subtasks,
        attachments,
        comments
    };
}

router.use(requireAuth);

// GET /api/task-detail/:id
// Lấy chi tiết task cho task_detail_screen.dart.
router.get('/:id', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        if (!taskId) {
            return res.status(400).json({
                success: false,
                message: 'ID nhiệm vụ không hợp lệ.'
            });
        }

        const data = await buildTaskDetail(taskId, req.user.id);
        if (!data) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền xem.'
            });
        }

        return res.json({ success: true, data });
    } catch (err) {
        console.error('Lỗi lấy chi tiết nhiệm vụ:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy chi tiết nhiệm vụ.',
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
            Object.prototype.hasOwnProperty.call(req.body, 'assignee_id') ||
            Object.prototype.hasOwnProperty.call(req.body, 'assigneeId')
        ) {
            const assigneeId = Number(req.body.assignee_id || req.body.assigneeId);
            fields.push('assignee_id = ?');
            values.push(Number.isInteger(assigneeId) && assigneeId > 0 ? assigneeId : null);
        }

        if (Object.prototype.hasOwnProperty.call(req.body, 'status') || Object.prototype.hasOwnProperty.call(req.body, 'status_code')) {
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
// Cập nhật trạng thái task: todo / in_progress / review / done.
router.patch('/:id/status', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const status = normalizeTaskStatus(req.body.status || req.body.status_code);

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiệm vụ không hợp lệ.' });
        }

        if (!TASK_STATUSES.includes(status)) {
            return res.status(400).json({ success: false, message: 'Trạng thái nhiệm vụ không hợp lệ.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
        }

        await pool.query('UPDATE tasks SET status = ? WHERE id = ?', [status, taskId]);

        if (status === 'done' && task.assignee_id && Number(task.assignee_id) !== Number(req.user.id)) {
            await pool.query(
                `INSERT INTO notifications (user_id, type, content, data, \`read\`)
                 VALUES (?, 'task', ?, ?, 0)`,
                [
                    task.assignee_id,
                    `Nhiệm vụ ${task.title} đã được đánh dấu hoàn thành.`,
                    JSON.stringify({ task_id: taskId, project_id: task.project_id })
                ]
            );
        }

        const data = await buildTaskDetail(taskId, req.user.id);
        return res.json({
            success: true,
            message: 'Cập nhật trạng thái nhiệm vụ thành công.',
            data
        });
    } catch (err) {
        console.error('Lỗi cập nhật trạng thái nhiệm vụ:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật trạng thái nhiệm vụ.',
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
// Thêm subtask mới.
router.post('/:id/subtasks', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const title = String(req.body.title || '').trim();

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiệm vụ không hợp lệ.' });
        }

        if (!title) {
            return res.status(400).json({ success: false, message: 'Tên subtask không được để trống.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
        }

        if (!(await tableExists(pool, 'task_subtasks'))) {
            return res.status(501).json({ success: false, message: 'Database chưa có bảng task_subtasks.' });
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
            message: 'Thêm subtask thành công.',
            data: mapSubtask(rows[0])
        });
    } catch (err) {
        console.error('Lỗi thêm subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể thêm subtask.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id/subtasks/:subtaskId
// Tick/bỏ tick hoặc đổi tên subtask.
router.patch('/:id/subtasks/:subtaskId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const subtaskId = Number(req.params.subtaskId);

        if (!taskId || !subtaskId) {
            return res.status(400).json({ success: false, message: 'ID subtask không hợp lệ.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
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
                return res.status(400).json({ success: false, message: 'Tên subtask không được để trống.' });
            }
            fields.push('title = ?');
            values.push(title);
        }

        if (fields.length === 0) {
            return res.status(400).json({ success: false, message: 'Không có thông tin nào để cập nhật.' });
        }

        values.push(subtaskId, taskId);
        const [result] = await pool.query(
            `UPDATE task_subtasks SET ${fields.join(', ')} WHERE id = ? AND task_id = ?`,
            values
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy subtask.' });
        }

        const [rows] = await pool.query(
            `SELECT id, task_id, title, is_completed, created_at, updated_at
             FROM task_subtasks WHERE id = ? LIMIT 1`,
            [subtaskId]
        );

        return res.json({
            success: true,
            message: 'Cập nhật subtask thành công.',
            data: mapSubtask(rows[0])
        });
    } catch (err) {
        console.error('Lỗi cập nhật subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật subtask.',
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
            return res.status(400).json({ success: false, message: 'ID subtask không hợp lệ.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
        }

        const [result] = await pool.query(
            'DELETE FROM task_subtasks WHERE id = ? AND task_id = ?',
            [subtaskId, taskId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy subtask.' });
        }

        return res.json({ success: true, message: 'Xóa subtask thành công.' });
    } catch (err) {
        console.error('Lỗi xóa subtask:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa subtask.',
            error: err.message
        });
    }
});

// POST /api/task-detail/:id/attachments
// Lưu metadata file đính kèm. Upload file nhị phân nên xử lý ở endpoint upload riêng.
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
            return res.status(400).json({ success: false, message: 'ID nhiệm vụ không hợp lệ.' });
        }

        if (!fileName || (!fileUrl && !fileBase64)) {
            return res.status(400).json({ success: false, message: 'Tên file và đường dẫn file không được để trống.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
        }

        if (!(await tableExists(pool, 'task_attachments'))) {
            return res.status(501).json({ success: false, message: 'Database chưa có bảng task_attachments.' });
        }

        if (fileBase64) {
            const savedFile = saveBase64File({ fileName, fileBase64 });
            if (savedFile) {
                fileUrl = savedFile.file_url;
                fileSize = savedFile.file_size;
            }
        }

        const normalizedType = ['image', 'video', 'document'].includes(fileType) ? fileType : 'document';
        const [result] = await pool.query(
            `INSERT INTO task_attachments
                (task_id, uploader_id, file_name, file_url, file_type, mime_type, file_size)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [taskId, req.user.id, fileName, fileUrl, normalizedType, mimeType, fileSize]
        );

        const attachments = await getAttachments(taskId);
        return res.status(201).json({
            success: true,
            message: 'Thêm tài liệu đính kèm thành công.',
            data: attachments.find((attachment) => Number(attachment.id) === Number(result.insertId)) || null
        });
    } catch (err) {
        console.error('Lỗi thêm tài liệu đính kèm:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể thêm tài liệu đính kèm.',
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
            return res.status(400).json({ success: false, message: 'ID tài liệu không hợp lệ.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền sửa.' });
        }

        const [result] = await pool.query(
            'DELETE FROM task_attachments WHERE id = ? AND task_id = ?',
            [attachmentId, taskId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy tài liệu đính kèm.' });
        }

        return res.json({ success: true, message: 'Xóa tài liệu đính kèm thành công.' });
    } catch (err) {
        console.error('Lỗi xóa tài liệu đính kèm:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa tài liệu đính kèm.',
            error: err.message
        });
    }
});

// POST /api/task-detail/:id/comments
// Hoạt động khi database có bảng task_comments(id, task_id, user_id, content, created_at).
router.post('/:id/comments', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const content = String(req.body.content || '').trim();

        if (!taskId) {
            return res.status(400).json({ success: false, message: 'ID nhiệm vụ không hợp lệ.' });
        }

        if (!content) {
            return res.status(400).json({ success: false, message: 'Nội dung bình luận không được để trống.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền bình luận.' });
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
            message: 'Thêm bình luận thành công.',
            data: mapComment(rows[0], req.user.id)
        });
    } catch (err) {
        console.error('Lỗi thêm bình luận:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể thêm bình luận.',
            error: err.message
        });
    }
});

// PATCH /api/task-detail/:id/comments/:commentId
// Chỉ người tạo bình luận mới được sửa nội dung bình luận của mình.
router.patch('/:id/comments/:commentId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const commentId = Number(req.params.commentId);
        const content = String(req.body.content || '').trim();

        if (!taskId || !commentId) {
            return res.status(400).json({ success: false, message: 'ID bình luận không hợp lệ.' });
        }

        if (!content) {
            return res.status(400).json({ success: false, message: 'Nội dung bình luận không được để trống.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền xem.' });
        }

        await ensureTaskCommentsTable(pool);

        const [result] = await pool.query(
            'UPDATE task_comments SET content = ? WHERE id = ? AND task_id = ? AND user_id = ?',
            [content, commentId, taskId, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy bình luận của bạn.' });
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
            message: 'Cập nhật bình luận thành công.',
            data: mapComment(rows[0], req.user.id)
        });
    } catch (err) {
        console.error('Lỗi cập nhật bình luận:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật bình luận.',
            error: err.message
        });
    }
});

// DELETE /api/task-detail/:id/comments/:commentId
// Chỉ người tạo bình luận mới được xóa bình luận của mình.
router.delete('/:id/comments/:commentId', async (req, res) => {
    try {
        const taskId = Number(req.params.id);
        const commentId = Number(req.params.commentId);

        if (!taskId || !commentId) {
            return res.status(400).json({ success: false, message: 'ID bình luận không hợp lệ.' });
        }

        const task = await getAccessibleTask(taskId, req.user.id);
        if (!task) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy nhiệm vụ hoặc bạn không có quyền xem.' });
        }

        await ensureTaskCommentsTable(pool);

        const [result] = await pool.query(
            'DELETE FROM task_comments WHERE id = ? AND task_id = ? AND user_id = ?',
            [commentId, taskId, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: 'Không tìm thấy bình luận của bạn.' });
        }

        return res.json({ success: true, message: 'Xóa bình luận thành công.' });
    } catch (err) {
        console.error('Lỗi xóa bình luận:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xóa bình luận.',
            error: err.message
        });
    }
});

module.exports = router;
