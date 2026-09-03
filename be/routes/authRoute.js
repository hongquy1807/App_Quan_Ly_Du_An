const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const router = express.Router();

const dbConfig = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
};

const pool = mysql.createPool({
    ...dbConfig,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

const JWT_SECRET = process.env.JWT_SECRET || 'quanlyduan-dev-secret';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';
const DEFAULT_SYSTEM_ROLE_ID = Number(process.env.DEFAULT_SYSTEM_ROLE_ID || 2);
const ADMIN_SYSTEM_ROLE_ID = Number(process.env.ADMIN_SYSTEM_ROLE_ID || 1);
const RESET_TOKEN_TTL_MS = 15 * 60 * 1000;
const REGISTER_OTP_TTL_MS = 5 * 60 * 1000;

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase();
}

function generateOtp() {
    return String(Math.floor(100000 + Math.random() * 900000));
}

async function ensureRegistrationOtpTable() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS registration_otps (
            id INT AUTO_INCREMENT PRIMARY KEY,
            email VARCHAR(255) NOT NULL,
            name VARCHAR(255) NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            system_role_id INT NULL,
            otp_hash VARCHAR(255) NOT NULL,
            expires_at BIGINT NOT NULL,
            attempts INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_registration_otps_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

function createMailTransporter() {
    const host = process.env.SMTP_HOST;
    const port = Number(process.env.SMTP_PORT || 587);
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !user || !pass) return null;

    return nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass }
    });
}

async function sendRegistrationOtpEmail(email, name, otp) {
    const transporter = createMailTransporter();
    if (!transporter) {
        if (process.env.OTP_DELIVERY === 'console' && process.env.NODE_ENV !== 'production') {
            console.log(`[OTP đăng ký] ${email}: ${otp}`);
            return { sent: false, delivery: 'console' };
        }
        throw new Error('Chưa cấu hình SMTP để gửi mã OTP qua email.');
    }

    const from = process.env.SMTP_FROM || process.env.SMTP_USER;
    await transporter.sendMail({
        from,
        to: email,
        subject: 'Mã OTP đăng ký tài khoản Quản lý dự án',
        text: `Xin chào ${name},\n\nMã OTP đăng ký tài khoản của bạn là: ${otp}\nMã có hiệu lực trong 5 phút.\n\nNếu bạn không thực hiện đăng ký, vui lòng bỏ qua email này.`,
        html: `
            <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111827">
                <h2>Quản lý dự án</h2>
                <p>Xin chào <strong>${name}</strong>,</p>
                <p>Mã OTP đăng ký tài khoản của bạn là:</p>
                <div style="font-size:28px;font-weight:700;letter-spacing:8px;color:#6C5CE7">${otp}</div>
                <p>Mã có hiệu lực trong 5 phút.</p>
                <p>Nếu bạn không thực hiện đăng ký, vui lòng bỏ qua email này.</p>
            </div>
        `
    });

    return { sent: true };
}

async function sendPasswordResetOtpEmail(email, name, otp) {
    const transporter = createMailTransporter();
    if (!transporter) {
        if (process.env.OTP_DELIVERY === 'console' && process.env.NODE_ENV !== 'production') {
            console.log(`[OTP khôi phục] ${email}: ${otp}`);
            return { sent: false, delivery: 'console' };
        }
        throw new Error('Chưa cấu hình SMTP để gửi mã OTP qua email.');
    }

    const from = process.env.SMTP_FROM || process.env.SMTP_USER;
    await transporter.sendMail({
        from,
        to: email,
        subject: 'Mã OTP khôi phục mật khẩu Quản lý dự án',
        text: `Xin chào ${name},\n\nMã OTP khôi phục mật khẩu của bạn là: ${otp}\nMã có hiệu lực trong 15 phút.\n\nNếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.`,
        html: `
            <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111827">
                <h2>Quản lý dự án</h2>
                <p>Xin chào <strong>${name}</strong>,</p>
                <p>Mã OTP khôi phục mật khẩu của bạn là:</p>
                <div style="font-size:28px;font-weight:700;letter-spacing:8px;color:#6C5CE7">${otp}</div>
                <p>Mã có hiệu lực trong 15 phút.</p>
                <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
            </div>
        `
    });

    return { sent: true };
}

function buildUserResponse(user) {
    return {
        id: user.id,
        email: user.email,
        name: user.name,
        system_role_id: user.system_role_id,
        role_name: user.role_name || null,
        created_at: user.created_at,
        last_login_at: user.last_login_at
    };
}

async function findUserByEmail(email) {
    const [rows] = await pool.query(
        `SELECT u.id, u.email, u.password, u.name, u.created_at, u.last_login_at,
                u.system_role_id, r.name AS role_name
         FROM users u
         LEFT JOIN roles r ON r.id = u.system_role_id
         WHERE u.email = ?
         LIMIT 1`,
        [email]
    );

    return rows[0] || null;
}

async function roleExists(roleId) {
    if (!roleId) return false;

    const [rows] = await pool.query(
        'SELECT id FROM roles WHERE id = ? LIMIT 1',
        [roleId]
    );

    return rows.length > 0;
}

function createAuthToken(user) {
    return jwt.sign(
        {
            id: user.id,
            email: user.email,
            system_role_id: user.system_role_id
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
    );
}

function isAdminUser(user) {
    const roleName = String(user?.role_name || '').trim().toLowerCase();
    return Number(user?.system_role_id) === ADMIN_SYSTEM_ROLE_ID ||
        ['admin', 'administrator', 'quan tri vien', 'quản trị viên'].includes(roleName);
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

    if (storedPassword === enteredPassword) {
        return true;
    }

    return false;
}

// POST /api/auth/register
// Tao OTP dang ky, chua tao user cho den khi xac thuc OTP thanh cong.
router.post('/register', async (req, res) => {
    try {
        await ensureRegistrationOtpTable();

        const email = normalizeEmail(req.body.email);
        const password = String(req.body.password || '');
        const name = String(req.body.name || '').trim();
        const requestedRoleId = req.body.system_role_id ? Number(req.body.system_role_id) : null;

        if (!email || !emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Email không hợp lệ.'
            });
        }

        if (!password || password.length < 6) {
            return res.status(400).json({
                success: false,
                message: 'Mật khẩu phải có ít nhất 6 ký tự.'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập họ tên.'
            });
        }

        const existedUser = await findUserByEmail(email);
        if (existedUser) {
            return res.status(409).json({
                success: false,
                message: 'Email này đã được đăng ký.'
            });
        }

        let systemRoleId = requestedRoleId || DEFAULT_SYSTEM_ROLE_ID;
        if (!(await roleExists(systemRoleId))) {
            systemRoleId = null;
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const otp = generateOtp();
        const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
        const expiresAt = Date.now() + REGISTER_OTP_TTL_MS;

        await pool.query(
            `INSERT INTO registration_otps (email, name, password_hash, system_role_id, otp_hash, expires_at, attempts)
             VALUES (?, ?, ?, ?, ?, ?, 0)
             ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                password_hash = VALUES(password_hash),
                system_role_id = VALUES(system_role_id),
                otp_hash = VALUES(otp_hash),
                expires_at = VALUES(expires_at),
                attempts = 0,
                created_at = CURRENT_TIMESTAMP`,
            [email, name, hashedPassword, systemRoleId, otpHash, expiresAt]
        );

        const mailResult = await sendRegistrationOtpEmail(email, name, otp);

        return res.status(200).json({
            success: true,
            message: mailResult.delivery === 'console'
                ? 'Mã OTP đã được in trong terminal backend.'
                : 'Đã gửi mã OTP đến email của bạn.',
            email,
            expires_in_seconds: Math.floor(REGISTER_OTP_TTL_MS / 1000)
        });
    } catch (err) {
        console.error('Lỗi đăng ký:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể tạo mã OTP đăng ký.',
            error: err.message
        });
    }
});

// POST /api/auth/verify-register-otp
router.post('/verify-register-otp', async (req, res) => {
    const conn = await pool.getConnection();
    try {
        await ensureRegistrationOtpTable();

        const email = normalizeEmail(req.body.email);
        const otp = String(req.body.otp || '').trim();

        if (!email || !emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Email không hợp lệ.'
            });
        }

        if (!/^\d{6}$/.test(otp)) {
            return res.status(400).json({
                success: false,
                message: 'Mã OTP phải gồm 6 chữ số.'
            });
        }

        await conn.beginTransaction();

        const existedUser = await findUserByEmail(email);
        if (existedUser) {
            await conn.query('DELETE FROM registration_otps WHERE email = ?', [email]);
            await conn.commit();
            return res.status(409).json({
                success: false,
                message: 'Email này đã được đăng ký.'
            });
        }

        const [otpRows] = await conn.query(
            'SELECT * FROM registration_otps WHERE email = ? LIMIT 1 FOR UPDATE',
            [email]
        );

        const pending = otpRows[0];
        if (!pending) {
            await conn.rollback();
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy yêu cầu đăng ký. Vui lòng đăng ký lại.'
            });
        }

        if (Number(pending.expires_at) < Date.now()) {
            await conn.query('DELETE FROM registration_otps WHERE email = ?', [email]);
            await conn.commit();
            return res.status(400).json({
                success: false,
                message: 'Mã OTP đã hết hạn. Vui lòng đăng ký lại để nhận mã mới.'
            });
        }

        if (Number(pending.attempts) >= 5) {
            await conn.query('DELETE FROM registration_otps WHERE email = ?', [email]);
            await conn.commit();
            return res.status(429).json({
                success: false,
                message: 'Bạn đã nhập sai quá nhiều lần. Vui lòng đăng ký lại.'
            });
        }

        const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
        if (otpHash !== pending.otp_hash) {
            await conn.query(
                'UPDATE registration_otps SET attempts = attempts + 1 WHERE email = ?',
                [email]
            );
            await conn.commit();
            return res.status(400).json({
                success: false,
                message: 'Mã OTP không đúng.'
            });
        }

        const [result] = await conn.query(
            `INSERT INTO users (email, password, name, system_role_id)
             VALUES (?, ?, ?, ?)`,
            [pending.email, pending.password_hash, pending.name, pending.system_role_id]
        );

        await conn.query('DELETE FROM registration_otps WHERE email = ?', [email]);
        await conn.commit();

        const user = {
            id: result.insertId,
            email: pending.email,
            name: pending.name,
            system_role_id: pending.system_role_id,
            role_name: null,
            created_at: new Date(),
            last_login_at: null
        };

        return res.status(201).json({
            success: true,
            message: 'Đăng ký tài khoản thành công.',
            user: buildUserResponse(user)
        });
    } catch (err) {
        try {
            await conn.rollback();
        } catch (_) {}
        console.error('Lỗi xác thực OTP đăng ký:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xác thực OTP đăng ký.',
            error: err.message
        });
    } finally {
        conn.release();
    }
});

// Legacy register handler, kept below for compatibility but shadowed by OTP handler above.
// POST /api/auth/register
router.post('/register', async (req, res) => {
    try {
        const email = normalizeEmail(req.body.email);
        const password = String(req.body.password || '');
        const name = String(req.body.name || '').trim();
        const requestedRoleId = req.body.system_role_id ? Number(req.body.system_role_id) : null;

        if (!email || !emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Email không hợp lệ.'
            });
        }

        if (!password || password.length < 6) {
            return res.status(400).json({
                success: false,
                message: 'Mật khẩu phải có ít nhất 6 ký tự.'
            });
        }

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập họ tên.'
            });
        }

        const existedUser = await findUserByEmail(email);
        if (existedUser) {
            return res.status(409).json({
                success: false,
                message: 'Email này đã được đăng ký.'
            });
        }

        let systemRoleId = requestedRoleId || DEFAULT_SYSTEM_ROLE_ID;
        if (!(await roleExists(systemRoleId))) {
            systemRoleId = null;
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const [result] = await pool.query(
            `INSERT INTO users (email, password, name, system_role_id)
             VALUES (?, ?, ?, ?)`,
            [email, hashedPassword, name, systemRoleId]
        );

        const user = {
            id: result.insertId,
            email,
            name,
            system_role_id: systemRoleId,
            role_name: null,
            created_at: new Date(),
            last_login_at: null
        };

        const token = createAuthToken(user);

        return res.status(201).json({
            success: true,
            message: 'Đăng ký tài khoản thành công.',
            token,
            user: buildUserResponse(user)
        });
    } catch (err) {
        console.error('Lỗi đăng ký:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể đăng ký tài khoản.',
            error: err.message
        });
    }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
    try {
        const email = normalizeEmail(req.body.email);
        const password = String(req.body.password || '');

        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập email và mật khẩu.'
            });
        }

        const user = await findUserByEmail(email);
        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Email hoặc mật khẩu không đúng.'
            });
        }

        const isPasswordValid = await verifyPassword(password, user.password);

        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Email hoặc mật khẩu không đúng.'
            });
        }

        await pool.query(
            'UPDATE users SET last_login_at = NOW() WHERE id = ?',
            [user.id]
        );

        user.last_login_at = new Date();
        const token = createAuthToken(user);

        return res.json({
            success: true,
            message: 'Đăng nhập thành công.',
            token,
            user: buildUserResponse(user)
        });
    } catch (err) {
        console.error('Lỗi đăng nhập:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể đăng nhập.',
            error: err.message
        });
    }
});

// POST /api/auth/admin-login
// Dang nhap rieng cho web admin. Chi tai khoan co role Admin moi duoc vao.
router.post('/admin-login', async (req, res) => {
    try {
        const email = normalizeEmail(req.body.email);
        const password = String(req.body.password || '');

        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập email và mật khẩu.'
            });
        }

        const user = await findUserByEmail(email);
        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Email hoặc mật khẩu không đúng.'
            });
        }

        const isPasswordValid = await verifyPassword(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Email hoặc mật khẩu không đúng.'
            });
        }

        if (!isAdminUser(user)) {
            return res.status(403).json({
                success: false,
                message: 'Tài khoản này không có quyền truy cập trang admin.'
            });
        }

        await pool.query(
            'UPDATE users SET last_login_at = NOW() WHERE id = ?',
            [user.id]
        );

        user.last_login_at = new Date();
        const token = createAuthToken(user);

        return res.json({
            success: true,
            message: 'Đăng nhập admin thành công.',
            token,
            user: buildUserResponse(user)
        });
    } catch (err) {
        console.error('Lỗi đăng nhập admin:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể đăng nhập admin.',
            error: err.message
        });
    }
});

// POST /api/auth/forgot-password
router.post('/forgot-password', async (req, res) => {
    try {
        const email = normalizeEmail(req.body.email);

        if (!email || !emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Email không hợp lệ.'
            });
        }

        const user = await findUserByEmail(email);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy tài khoản với email này.'
            });
        }

        const otp = generateOtp();
        const resetToken = crypto.createHash('sha256').update(otp).digest('hex');
        const expiresAt = Date.now() + RESET_TOKEN_TTL_MS;

        await pool.query('DELETE FROM password_resets WHERE user_id = ?', [user.id]);
        await pool.query(
            `INSERT INTO password_resets (user_id, token, expires_at)
             VALUES (?, ?, ?)`,
            [user.id, resetToken, expiresAt]
        );

        const mailResult = await sendPasswordResetOtpEmail(email, user.name || email, otp);

        return res.json({
            success: true,
            message: mailResult.delivery === 'console'
                ? 'Mã OTP đã được in trong terminal backend.'
                : 'Đã gửi mã OTP khôi phục mật khẩu đến email của bạn.',
            email,
            expires_at: expiresAt,
            expires_in_seconds: Math.floor(RESET_TOKEN_TTL_MS / 1000)
        });
    } catch (err) {
        console.error('Lỗi quên mật khẩu:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xử lý yêu cầu quên mật khẩu.',
            error: err.message
        });
    }
});

// POST /api/auth/verify-reset-otp
router.post('/verify-reset-otp', async (req, res) => {
    try {
        const email = normalizeEmail(req.body.email);
        const otp = String(req.body.otp || '').trim();

        if (!email || !emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Email không hợp lệ.'
            });
        }

        if (!/^\d{6}$/.test(otp)) {
            return res.status(400).json({
                success: false,
                message: 'Mã OTP phải gồm 6 chữ số.'
            });
        }

        const resetToken = crypto.createHash('sha256').update(otp).digest('hex');
        const [resetRows] = await pool.query(
            `SELECT pr.id, pr.expires_at, u.email
             FROM password_resets pr
             INNER JOIN users u ON u.id = pr.user_id
             WHERE u.email = ? AND pr.token = ?
             LIMIT 1`,
            [email, resetToken]
        );

        const resetRequest = resetRows[0];
        if (!resetRequest || Number(resetRequest.expires_at) < Date.now()) {
            return res.status(400).json({
                success: false,
                message: 'Mã OTP không hợp lệ hoặc đã hết hạn.'
            });
        }

        return res.json({
            success: true,
            message: 'Xác thực OTP thành công.',
            email,
            reset_token: resetToken
        });
    } catch (err) {
        console.error('Lỗi xác thực OTP khôi phục mật khẩu:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xác thực OTP khôi phục mật khẩu.',
            error: err.message
        });
    }
});

// POST /api/auth/reset-password
router.post('/reset-password', async (req, res) => {
    try {
        const token = String(req.body.token || '').trim();
        const newPassword = String(req.body.new_password || req.body.password || '');

        if (!token) {
            return res.status(400).json({
                success: false,
                message: 'Vui lòng nhập mã đặt lại mật khẩu.'
            });
        }

        if (!newPassword || newPassword.length < 6) {
            return res.status(400).json({
                success: false,
                message: 'Mật khẩu mới phải có ít nhất 6 ký tự.'
            });
        }

        const [resetRows] = await pool.query(
            `SELECT pr.id, pr.user_id, pr.expires_at, u.email
             FROM password_resets pr
             INNER JOIN users u ON u.id = pr.user_id
             WHERE pr.token = ?
             LIMIT 1`,
            [token]
        );

        const resetRequest = resetRows[0];
        if (!resetRequest || Number(resetRequest.expires_at) < Date.now()) {
            return res.status(400).json({
                success: false,
                message: 'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.'
            });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);

        await pool.query(
            'UPDATE users SET password = ? WHERE id = ?',
            [hashedPassword, resetRequest.user_id]
        );
        await pool.query(
            'DELETE FROM password_resets WHERE user_id = ?',
            [resetRequest.user_id]
        );

        return res.json({
            success: true,
            message: 'Đặt lại mật khẩu thành công.'
        });
    } catch (err) {
        console.error('Lỗi đặt lại mật khẩu:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể đặt lại mật khẩu.',
            error: err.message
        });
    }
});

module.exports = router;

