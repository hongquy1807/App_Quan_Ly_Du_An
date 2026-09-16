const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

let firebaseAdmin = null;
let firebaseReady = false;

try {
    firebaseAdmin = require('firebase-admin');
} catch (err) {
    firebaseAdmin = null;
}

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

async function ensurePushTokenTable(connection = pool) {
    await connection.query(
        `CREATE TABLE IF NOT EXISTS user_push_tokens (
            id INT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL,
            token VARCHAR(255) NOT NULL,
            platform VARCHAR(32) DEFAULT NULL,
            device_id VARCHAR(128) DEFAULT NULL,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY user_push_tokens_token_unique (token),
            KEY user_push_tokens_user_idx (user_id),
            CONSTRAINT user_push_tokens_user_fk
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
    );
}

function initializeFirebase() {
    if (firebaseReady) return true;
    if (!firebaseAdmin) return false;

    if (firebaseAdmin.apps.length > 0) {
        firebaseReady = true;
        return true;
    }

    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const defaultServiceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
        (fs.existsSync(defaultServiceAccountPath) ? defaultServiceAccountPath : '');

    try {
        if (serviceAccountJson) {
            firebaseAdmin.initializeApp({
                credential: firebaseAdmin.credential.cert(JSON.parse(serviceAccountJson))
            });
        } else if (serviceAccountPath) {
            firebaseAdmin.initializeApp({
                credential: firebaseAdmin.credential.cert(require(serviceAccountPath))
            });
        } else {
            console.warn('Firebase Admin chua duoc cau hinh. Thieu FIREBASE_SERVICE_ACCOUNT_PATH hoac be/firebase-service-account.json.');
            return false;
        }
        firebaseReady = true;
        return true;
    } catch (err) {
        console.warn('Khong the khoi tao Firebase Admin:', err.message);
        return false;
    }
}

async function registerPushToken({ userId, token, platform, deviceId }) {
    const cleanToken = String(token || '').trim();
    if (!userId || !cleanToken) return false;

    await ensurePushTokenTable(pool);
    await pool.query(
        `INSERT INTO user_push_tokens (user_id, token, platform, device_id, is_active)
         VALUES (?, ?, ?, ?, 1)
         ON DUPLICATE KEY UPDATE
            user_id = VALUES(user_id),
            platform = VALUES(platform),
            device_id = VALUES(device_id),
            is_active = 1,
            updated_at = NOW()`,
        [userId, cleanToken, platform || null, deviceId || null]
    );
    return true;
}

async function unregisterPushToken({ userId, token }) {
    const cleanToken = String(token || '').trim();
    if (!userId || !cleanToken) return false;

    await ensurePushTokenTable(pool);
    await pool.query(
        'UPDATE user_push_tokens SET is_active = 0 WHERE user_id = ? AND token = ?',
        [userId, cleanToken]
    );
    return true;
}

async function sendPushToUser(userId, { title, body, data = {} }) {
    if (!initializeFirebase()) {
        console.warn(`Bo qua push cho user ${userId}: Firebase Admin chua san sang.`);
        return { sent: 0, skipped: true, reason: 'firebase_not_ready' };
    }

    await ensurePushTokenTable(pool);
    const [rows] = await pool.query(
        `SELECT token
         FROM user_push_tokens
         WHERE user_id = ? AND is_active = 1`,
        [userId]
    );
    if (rows.length === 0) {
        console.warn(`Bo qua push cho user ${userId}: chua co FCM token.`);
        return { sent: 0, reason: 'no_tokens' };
    }

    const stringData = Object.fromEntries(
        Object.entries(data || {}).map(([key, value]) => [key, String(value ?? '')])
    );
    const tokens = rows.map((row) => row.token);
    const response = await firebaseAdmin.messaging().sendEachForMulticast({
        tokens,
        notification: {
            title: title || 'Quản lý dự án',
            body: body || 'Bạn có thông báo mới.'
        },
        data: stringData,
        android: {
            priority: 'high',
            notification: {
                channelId: 'quanlyduan_default',
                sound: 'default'
            }
        }
    });

    const invalidTokens = [];
    response.responses.forEach((result, index) => {
        const code = result.error?.code || '';
        if (
            code.includes('registration-token-not-registered') ||
            code.includes('invalid-registration-token')
        ) {
            invalidTokens.push(tokens[index]);
        }
    });

    if (invalidTokens.length > 0) {
        await pool.query(
            'UPDATE user_push_tokens SET is_active = 0 WHERE token IN (?)',
            [invalidTokens]
        );
    }

    return { sent: response.successCount, failed: response.failureCount };
}

module.exports = {
    ensurePushTokenTable,
    registerPushToken,
    unregisterPushToken,
    sendPushToUser
};
