const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') }); // Load biến môi trường từ file .env
const express = require('express');
const mysql = require('mysql2/promise'); // Sử dụng thư viện mysql2 với hỗ trợ Promise (async/await)
const cors = require('cors');

const app = express();
const uploadDir = path.join(__dirname, 'upload');
const adminWebDir = path.join(__dirname, '..', 'web', 'admin');
// ==========================================
// 1. CẤU HÌNH CÁC MIDDLEWARE CƠ BẢN
// ==========================================
app.use(cors()); // Cho phép Flutter gọi API từ server này
app.use(express.json({ limit: '50mb' })); // Bắt buộc phải có để đọc dữ liệu JSON gửi từ Flutter lên

// ==========================================
// 2. CẤU HÌNH KẾT NỐI MYSQL
// ==========================================
app.use('/upload', express.static(uploadDir));
app.use('/admin', express.static(adminWebDir));

const dbConfig = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
};

// ==========================================
// 3. MIDDLEWARE KIỂM TRA XÁC THỰC (Cho API Mobile)
// ==========================================
const checkAuthAPI = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (authHeader) {
        next(); // Token hợp lệ thì cho đi tiếp vào API
    } else {
        return res.status(401).json({ 
            success: false, 
            message: "Bạn chưa đăng nhập hoặc phiên làm việc đã hết hạn!" 
        });
    }
};

// ==========================================
// 4. CÁC API KHỞI TẠO BAN ĐẦU
// ==========================================

// API trang chủ (Kiểm tra xem server nodejs có đang sống không)
app.get('/', (req, res) => {
    res.json({
        app: "Quản Lý Dự Án",
        version: "1.0.0",
        database_type: "MySQL",
        message: "API Server Node.js đang hoạt động ổn định! 🚀"
    });
});

// ==========================================
// 5. NƠI KHAI BÁO CÁC ROUTER CHO DỰ ÁN MỚI
// ==========================================
const authRoutes = require('./routes/authRoute');
const homeRoutes = require('./routes/homeRoute');
const notificationsRoutes = require('./routes/notificationsRoute');
const profileRoutes = require('./routes/profileRoute');
const projectRoutes = require('./routes/projectRoute');
const projectDetailRoutes = require('./routes/projectDetailRoute');
const tasksDetailRoutes = require('./routes/tasksDetailRoute');
const timelineRoutes = require('./routes/timelineRoute');
const projectChatRoutes = require('./routes/projectChatRoute');
const feedbackRoutes = require('./routes/feedbackRoute');
const chatbotRoutes = require('./routes/chatbotRoute');
const friendRoutes = require('./routes/friendRoute');
const cvRoutes = require('./routes/cvRoute');
//
app.use('/api/auth', authRoutes);
app.use('/api/home', homeRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/project-detail', checkAuthAPI, projectDetailRoutes);
app.use('/api/task-detail', checkAuthAPI, tasksDetailRoutes);
app.use('/api/projects', checkAuthAPI, projectRoutes);
app.use('/api/timeline', checkAuthAPI, timelineRoutes);
app.use('/api/project-chat', checkAuthAPI, projectChatRoutes);
app.use('/api/feedback', checkAuthAPI, feedbackRoutes);
app.use('/api/chatbot', checkAuthAPI, chatbotRoutes);
app.use('/api/friends', checkAuthAPI, friendRoutes);
app.use('/api/cv', checkAuthAPI, cvRoutes);

app.use('/api', (req, res) => {
    return res.status(404).json({
        success: false,
        message: `Không tìm thấy API: ${req.method} ${req.originalUrl}`
    });
});

// ==========================================
// 6. CHẠY SERVER
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`=========================================`);
    console.log(`🚀 Server [Quản lý dự án] đang chạy tại cổng: ${PORT}`);
    console.log(`👉 Link kiểm tra: http://localhost:${PORT}/`);
    console.log(`=========================================`);
});
