const express = require('express');
const fs = require('fs');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');
const path = require('path');

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
const avatarUploadDir = path.join(__dirname, '..', 'upload', 'avatar');
const allowedAvatarExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);

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

function ensureAvatarUploadDir() {
    fs.mkdirSync(avatarUploadDir, { recursive: true });
}

function getAvatarExtension(fileName, mimeType) {
    const fileExt = path.extname(String(fileName || '')).toLowerCase();
    if (allowedAvatarExtensions.has(fileExt)) return fileExt;

    if (mimeType === 'image/jpeg') return '.jpg';
    if (mimeType === 'image/png') return '.png';
    if (mimeType === 'image/webp') return '.webp';

    return null;
}

function normalizeBase64Image(imageBase64) {
    const value = String(imageBase64 || '').trim();
    const match = value.match(/^data:(image\/(?:jpeg|png|webp));base64,(.+)$/);
    if (match) {
        return {
            mimeType: match[1],
            base64: match[2]
        };
    }

    return {
        mimeType: null,
        base64: value
    };
}

function formatDateOnly(value) {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return null;

    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    return `${day}/${month}/${year}`;
}

function parseDateOnly(value) {
    const raw = String(value || '').trim();
    if (!raw) return null;

    const slashMatch = raw.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (slashMatch) {
        const day = Number(slashMatch[1]);
        const month = Number(slashMatch[2]);
        const year = Number(slashMatch[3]);
        const date = new Date(year, month - 1, day);
        if (
            date.getFullYear() === year &&
            date.getMonth() === month - 1 &&
            date.getDate() === day
        ) {
            return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        }
        return undefined;
    }

    const dashMatch = raw.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (dashMatch) {
        const year = Number(dashMatch[1]);
        const month = Number(dashMatch[2]);
        const day = Number(dashMatch[3]);
        const date = new Date(year, month - 1, day);
        if (
            date.getFullYear() === year &&
            date.getMonth() === month - 1 &&
            date.getDate() === day
        ) {
            return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        }
    }

    return undefined;
}

router.use(requireAuth);

// GET /api/profile
// Trả về thông tin ngắn gọn dùng cho thẻ profile: avatar, họ tên, email.
router.get('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const [rows] = await pool.query(
            `SELECT id, name, email, avatar, birthday, address, phone
             FROM users
             WHERE id = ?
             LIMIT 1`,
            [userId]
        );

        const user = rows[0];
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tài khoản.'
            });
        }

        return res.json({
            success: true,
            data: {
                id: user.id,
                avatar: user.avatar,
                name: user.name,
                email: user.email,
                phone: user.phone,
                birthday: formatDateOnly(user.birthday),
                address: user.address
            }
        });
    } catch (err) {
        console.error('Profile API error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tải thông tin người dùng.'
        });
    }
});

// PATCH /api/profile
// Body JSON: { "name", "phone", "birthday", "address" }
router.patch('/', async (req, res) => {
    try {
        const userId = req.user.id;
        const name = String(req.body?.name || '').trim();
        const phone = String(req.body?.phone || '').trim() || null;
        const address = String(req.body?.address || '').trim() || null;
        const birthday = parseDateOnly(req.body?.birthday);

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập họ tên.'
            });
        }

        if (birthday === undefined) {
            return res.status(400).json({
                success: false,
                message: 'Ngày sinh không hợp lệ. Vui lòng dùng định dạng dd/mm/yyyy.'
            });
        }

        const [result] = await pool.query(
            `UPDATE users
             SET name = ?, phone = ?, birthday = ?, address = ?
             WHERE id = ?`,
            [name, phone, birthday, address, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tài khoản.'
            });
        }

        const [rows] = await pool.query(
            `SELECT id, name, email, avatar, birthday, address, phone
             FROM users
             WHERE id = ?
             LIMIT 1`,
            [userId]
        );
        const user = rows[0];

        return res.json({
            success: true,
            message: 'Đã cập nhật thông tin cá nhân.',
            data: {
                id: user.id,
                avatar: user.avatar,
                name: user.name,
                email: user.email,
                phone: user.phone,
                birthday: formatDateOnly(user.birthday),
                address: user.address
            }
        });
    } catch (err) {
        console.error('Update profile API error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật thông tin cá nhân.'
        });
    }
});

// PATCH /api/profile/avatar
// Body JSON:
// {
//   "fileName": "avatar.png",
//   "imageBase64": "data:image/png;base64,..." hoặc chuỗi base64 thuần
// }
router.patch('/avatar', async (req, res) => {
    try {
        const userId = req.user.id;
        const { fileName, imageBase64 } = req.body || {};

        if (!imageBase64) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng gửi dữ liệu ảnh đại diện.'
            });
        }

        const { mimeType, base64 } = normalizeBase64Image(imageBase64);
        const ext = getAvatarExtension(fileName, mimeType);
        if (!ext) {
            return res.status(400).json({
                success: false,
                message: 'Ảnh đại diện chỉ hỗ trợ JPG, PNG hoặc WEBP.'
            });
        }

        const imageBuffer = Buffer.from(base64, 'base64');
        if (!imageBuffer.length) {
            return res.status(400).json({
                success: false,
                message: 'Dữ liệu ảnh không hợp lệ.'
            });
        }

        const maxSizeInBytes = 5 * 1024 * 1024;
        if (imageBuffer.length > maxSizeInBytes) {
            return res.status(400).json({
                success: false,
                message: 'Ảnh đại diện không được vượt quá 5MB.'
            });
        }

        ensureAvatarUploadDir();

        const avatarFileName = `user-${userId}-${Date.now()}${ext}`;
        const avatarPath = path.join(avatarUploadDir, avatarFileName);
        const avatarUrl = `/upload/avatar/${avatarFileName}`;

        fs.writeFileSync(avatarPath, imageBuffer);

        const [result] = await pool.query(
            'UPDATE users SET avatar = ? WHERE id = ?',
            [avatarUrl, userId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tài khoản.'
            });
        }

        return res.json({
            success: true,
            message: 'Đã cập nhật ảnh đại diện.',
            data: {
                avatar: avatarUrl
            }
        });
    } catch (err) {
        console.error('Upload avatar API error:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể cập nhật ảnh đại diện.'
        });
    }
});

module.exports = router;
