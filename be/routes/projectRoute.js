const express = require('express');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
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
        completed_at: row.completed_at,
        completed_by: row.completed_by,
        completed_by_name: row.completed_by_name,
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

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function escapeXml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
}

function formatDate(value) {
    if (!value) return 'Chưa cập nhật';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return `${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}/${date.getFullYear()}`;
}

function formatDateTime(value) {
    const date = value ? new Date(value) : new Date();
    if (Number.isNaN(date.getTime())) return formatDate(new Date());
    return `${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}/${date.getFullYear()} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function taskStatusLabel(status) {
    if (status === 'done') return 'Hoàn thành';
    if (status === 'in_progress') return 'Đang làm';
    if (status === 'review') return 'Chờ duyệt';
    return 'Chưa nhận';
}

function buildCompletedProjectReport({ project, members, tasks }) {
    const completedTasks = tasks.filter((task) => task.status === 'done').length;
    const rows = tasks.map((task, index) => `
        <tr>
            <td>${index + 1}</td>
            <td>
                <strong>${escapeHtml(task.title)}</strong>
                <div class="muted">${escapeHtml(task.description || 'Không có mô tả')}</div>
            </td>
            <td>${escapeHtml(task.assignee_name || 'Cả team')}</td>
            <td>${escapeHtml(task.assignee_email || '')}</td>
            <td>${formatDate(task.start_date)}</td>
            <td>${formatDate(task.due_date)}</td>
            <td><span class="badge">${escapeHtml(taskStatusLabel(task.status))}</span></td>
        </tr>
    `).join('');

    const memberRows = members.map((member, index) => `
        <tr>
            <td>${index + 1}</td>
            <td>${escapeHtml(member.name)}</td>
            <td>${escapeHtml(member.email)}</td>
            <td>${escapeHtml(member.role_name || 'Thành viên')}</td>
        </tr>
    `).join('');

    return `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <title>Báo cáo dự án - ${escapeHtml(project.name)}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #1f2937; margin: 32px; line-height: 1.45; }
    h1 { color: #4f46e5; margin-bottom: 4px; }
    h2 { margin-top: 28px; color: #111827; }
    .muted { color: #6b7280; font-size: 13px; margin-top: 4px; }
    .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 22px 0; }
    .card { border: 1px solid #e5e7eb; border-radius: 12px; padding: 14px; background: #f9fafb; }
    .value { font-size: 24px; font-weight: 700; color: #4f46e5; }
    table { border-collapse: collapse; width: 100%; margin-top: 12px; }
    th, td { border: 1px solid #e5e7eb; padding: 10px; vertical-align: top; text-align: left; }
    th { background: #eef2ff; color: #3730a3; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 999px; background: #dcfce7; color: #047857; font-weight: 700; font-size: 12px; }
  </style>
</head>
<body>
  <h1>Báo cáo chi tiết dự án</h1>
  <div class="muted">Xuất ngày ${formatDate(new Date())}</div>

  <h2>${escapeHtml(project.name)}</h2>
  <p>${escapeHtml(project.description || 'Không có mô tả')}</p>

  <div class="summary">
    <div class="card"><div class="value">${members.length}</div><div>Thành viên</div></div>
    <div class="card"><div class="value">${tasks.length}</div><div>Tổng task</div></div>
    <div class="card"><div class="value">${completedTasks}</div><div>Task hoàn thành</div></div>
    <div class="card"><div class="value">${formatDate(project.completed_at)}</div><div>Ngày hoàn thành</div></div>
  </div>

  <p><strong>Trưởng dự án:</strong> ${escapeHtml(project.owner_name || 'Chưa cập nhật')}</p>
  <p><strong>Người đánh dấu hoàn thành:</strong> ${escapeHtml(project.completed_by_name || 'Chưa cập nhật')}</p>
  <p><strong>Thời gian dự án:</strong> ${formatDate(project.start_date)} - ${formatDate(project.end_date)}</p>

  <h2>Danh sách công việc</h2>
  <table>
    <thead>
      <tr>
        <th>STT</th>
        <th>Công việc</th>
        <th>Người thực hiện</th>
        <th>Email</th>
        <th>Ngày bắt đầu</th>
        <th>Hạn chót</th>
        <th>Trạng thái</th>
      </tr>
    </thead>
    <tbody>${rows || '<tr><td colspan="7">Không có công việc.</td></tr>'}</tbody>
  </table>

  <h2>Thành viên tham gia</h2>
  <table>
    <thead>
      <tr>
        <th>STT</th>
        <th>Họ tên</th>
        <th>Email</th>
        <th>Vai trò</th>
      </tr>
    </thead>
    <tbody>${memberRows || '<tr><td colspan="4">Không có thành viên.</td></tr>'}</tbody>
  </table>
</body>
</html>`;
}

function crc32(buffer) {
    let crc = ~0;
    for (let i = 0; i < buffer.length; i += 1) {
        crc ^= buffer[i];
        for (let j = 0; j < 8; j += 1) {
            crc = (crc >>> 1) ^ (0xEDB88320 & -(crc & 1));
        }
    }
    return (~crc) >>> 0;
}

function dosDateTime(date = new Date()) {
    const time = (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2);
    const dosDate = ((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
    return { time, date: dosDate };
}

function buildZip(files) {
    const localParts = [];
    const centralParts = [];
    let offset = 0;
    const stamp = dosDateTime();

    files.forEach((file) => {
        const nameBuffer = Buffer.from(file.name, 'utf8');
        const data = Buffer.isBuffer(file.data) ? file.data : Buffer.from(file.data, 'utf8');
        const crc = crc32(data);

        const local = Buffer.alloc(30);
        local.writeUInt32LE(0x04034b50, 0);
        local.writeUInt16LE(20, 4);
        local.writeUInt16LE(0x0800, 6);
        local.writeUInt16LE(0, 8);
        local.writeUInt16LE(stamp.time, 10);
        local.writeUInt16LE(stamp.date, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(data.length, 18);
        local.writeUInt32LE(data.length, 22);
        local.writeUInt16LE(nameBuffer.length, 26);
        local.writeUInt16LE(0, 28);
        localParts.push(local, nameBuffer, data);

        const central = Buffer.alloc(46);
        central.writeUInt32LE(0x02014b50, 0);
        central.writeUInt16LE(20, 4);
        central.writeUInt16LE(20, 6);
        central.writeUInt16LE(0x0800, 8);
        central.writeUInt16LE(0, 10);
        central.writeUInt16LE(stamp.time, 12);
        central.writeUInt16LE(stamp.date, 14);
        central.writeUInt32LE(crc, 16);
        central.writeUInt32LE(data.length, 20);
        central.writeUInt32LE(data.length, 24);
        central.writeUInt16LE(nameBuffer.length, 28);
        central.writeUInt16LE(0, 30);
        central.writeUInt16LE(0, 32);
        central.writeUInt16LE(0, 34);
        central.writeUInt16LE(0, 36);
        central.writeUInt32LE(0, 38);
        central.writeUInt32LE(offset, 42);
        centralParts.push(central, nameBuffer);

        offset += local.length + nameBuffer.length + data.length;
    });

    const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(0, 4);
    end.writeUInt16LE(0, 6);
    end.writeUInt16LE(files.length, 8);
    end.writeUInt16LE(files.length, 10);
    end.writeUInt32LE(centralSize, 12);
    end.writeUInt32LE(offset, 16);
    end.writeUInt16LE(0, 20);

    return Buffer.concat([...localParts, ...centralParts, end]);
}

function wText(value) {
    return `<w:t xml:space="preserve">${escapeXml(value)}</w:t>`;
}

function wRun(value, opts = {}) {
    const color = opts.color ? `<w:color w:val="${opts.color}"/>` : '';
    const bold = opts.bold ? '<w:b/><w:bCs/>' : '';
    const size = opts.size ? `<w:sz w:val="${opts.size * 2}"/><w:szCs w:val="${opts.size * 2}"/>` : '';
    return `<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>${bold}${color}${size}</w:rPr>${wText(value)}</w:r>`;
}

function wParagraph(value, opts = {}) {
    const align = opts.align ? `<w:jc w:val="${opts.align}"/>` : '';
    const spacing = `<w:spacing w:before="${opts.before || 0}" w:after="${opts.after ?? 100}"/>`;
    return `<w:p><w:pPr>${align}${spacing}</w:pPr>${wRun(value, opts)}</w:p>`;
}

function wHeading(value) {
    return `<w:p><w:pPr><w:spacing w:before="220" w:after="120"/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="2" w:color="655CF6"/></w:pBdr></w:pPr>${wRun(value.toUpperCase(), { bold: true, size: 14, color: '655CF6' })}</w:p>`;
}

function wCell(content, opts = {}) {
    const width = opts.width || 2400;
    const fill = opts.fill ? `<w:shd w:val="clear" w:color="auto" w:fill="${opts.fill}"/>` : '';
    const borders = opts.noBorder
        ? '<w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders>'
        : '<w:tcBorders><w:top w:val="single" w:sz="4" w:color="E5E7EB"/><w:left w:val="single" w:sz="4" w:color="E5E7EB"/><w:bottom w:val="single" w:sz="4" w:color="E5E7EB"/><w:right w:val="single" w:sz="4" w:color="E5E7EB"/></w:tcBorders>';
    const margins = '<w:tcMar><w:top w:w="140" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="140" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar>';
    return `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/>${fill}${borders}${margins}</w:tcPr>${content || '<w:p/>'}</w:tc>`;
}

function wTable(rows, widths, opts = {}) {
    const grid = widths.map((width) => `<w:gridCol w:w="${width}"/>`).join('');
    const borders = opts.noBorder
        ? '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
        : '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="E5E7EB"/><w:left w:val="single" w:sz="4" w:color="E5E7EB"/><w:bottom w:val="single" w:sz="4" w:color="E5E7EB"/><w:right w:val="single" w:sz="4" w:color="E5E7EB"/><w:insideH w:val="single" w:sz="4" w:color="E5E7EB"/><w:insideV w:val="single" w:sz="4" w:color="E5E7EB"/></w:tblBorders>';
    return `<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>${borders}</w:tblPr><w:tblGrid>${grid}</w:tblGrid>${rows.join('')}</w:tbl>`;
}

function wHeaderCell(value, width) {
    return wCell(wParagraph(value, { bold: true, color: '3730A3', size: 10, after: 0 }), { width, fill: 'EEF2FF' });
}

function wBodyCell(value, width, opts = {}) {
    return wCell(wParagraph(value || opts.empty || 'Chưa cập nhật', { size: opts.size || 9.5, color: opts.color || '1F2937', after: 0 }), { width });
}

function buildTaskTable(tasks, emptyText) {
    const widths = [600, 2600, 2500, 1300, 1300, 1100];
    const rows = [
        `<w:tr>${wHeaderCell('STT', widths[0])}${wHeaderCell('Nhiệm vụ', widths[1])}${wHeaderCell('Người thực hiện', widths[2])}${wHeaderCell('Bắt đầu', widths[3])}${wHeaderCell('Hạn chót', widths[4])}${wHeaderCell('Trạng thái', widths[5])}</w:tr>`
    ];

    if (tasks.length === 0) {
        rows.push(`<w:tr>${wBodyCell('', widths[0], { empty: '' })}${wBodyCell(emptyText, widths[1])}${wBodyCell('', widths[2], { empty: '' })}${wBodyCell('', widths[3], { empty: '' })}${wBodyCell('', widths[4], { empty: '' })}${wBodyCell('', widths[5], { empty: '' })}</w:tr>`);
        return wTable(rows, widths);
    }

    tasks.forEach((task, index) => {
        const assignee = task.assignee_name
            ? `${task.assignee_name}${task.assignee_email ? ` (${task.assignee_email})` : ''}`
            : 'Cả team';
        rows.push(`<w:tr>${wBodyCell(String(index + 1), widths[0])}${wBodyCell(`${task.title || ''}${task.description ? `\n${task.description}` : ''}`, widths[1])}${wBodyCell(assignee, widths[2])}${wBodyCell(formatDate(task.start_date), widths[3])}${wBodyCell(formatDate(task.due_date), widths[4])}${wBodyCell(taskStatusLabel(task.status), widths[5])}</w:tr>`);
    });

    return wTable(rows, widths);
}

function buildMemberTable(members) {
    const widths = [650, 3100, 3500, 2150];
    const rows = [
        `<w:tr>${wHeaderCell('STT', widths[0])}${wHeaderCell('Họ tên', widths[1])}${wHeaderCell('Email', widths[2])}${wHeaderCell('Vai trò', widths[3])}</w:tr>`
    ];

    if (members.length === 0) {
        rows.push(`<w:tr>${wBodyCell('', widths[0], { empty: '' })}${wBodyCell('Không có thành viên.', widths[1])}${wBodyCell('', widths[2], { empty: '' })}${wBodyCell('', widths[3], { empty: '' })}</w:tr>`);
        return wTable(rows, widths);
    }

    members.forEach((member, index) => {
        rows.push(`<w:tr>${wBodyCell(String(index + 1), widths[0])}${wBodyCell(member.name, widths[1])}${wBodyCell(member.email, widths[2])}${wBodyCell(member.role_name || 'Thành viên', widths[3])}</w:tr>`);
    });

    return wTable(rows, widths);
}

function buildProjectReportDocxBuffer({ project, members, tasks }) {
    const completedTasks = tasks.filter((task) => task.status === 'done');
    const incompleteTasks = tasks.filter((task) => task.status !== 'done');
    const summaryRows = [
        `<w:tr>${wCell(wParagraph('Thành viên', { bold: true, color: '655CF6', align: 'center', after: 40 }) + wParagraph(String(members.length), { bold: true, size: 20, align: 'center', after: 0 }), { width: 2350, fill: 'F5F3FF', noBorder: true })}${wCell(wParagraph('Tổng nhiệm vụ', { bold: true, color: '655CF6', align: 'center', after: 40 }) + wParagraph(String(tasks.length), { bold: true, size: 20, align: 'center', after: 0 }), { width: 2350, fill: 'F5F3FF', noBorder: true })}${wCell(wParagraph('Hoàn thành', { bold: true, color: '10B981', align: 'center', after: 40 }) + wParagraph(String(completedTasks.length), { bold: true, size: 20, align: 'center', after: 0 }), { width: 2350, fill: 'ECFDF5', noBorder: true })}${wCell(wParagraph('Chưa hoàn thành', { bold: true, color: 'EF4444', align: 'center', after: 40 }) + wParagraph(String(incompleteTasks.length), { bold: true, size: 20, align: 'center', after: 0 }), { width: 2350, fill: 'FEF2F2', noBorder: true })}</w:tr>`
    ];

    const body = [
        wParagraph('Thông tin dự án', { bold: true, size: 15, color: '655CF6', after: 80 }),
        wParagraph(`Tên dự án: ${project.name || 'Chưa cập nhật'}`, { bold: true, size: 11, color: '1F2937', after: 70 }),
        wParagraph(`Mô tả: ${project.description || 'Không có mô tả'}`, { size: 10.5, color: '374151', after: 70 }),
        wParagraph(`Thời gian dự án: ${formatDate(project.start_date)} - ${formatDate(project.end_date)}`, { size: 10.5, color: '374151', after: 120 }),
        wTable(summaryRows, [2350, 2350, 2350, 2350], { noBorder: true }),
        wHeading('Thành viên tham gia dự án'),
        buildMemberTable(members),
        wHeading('Tất cả nhiệm vụ của dự án'),
        buildTaskTable(tasks, 'Không có nhiệm vụ trong dự án.'),
        wHeading('Nhiệm vụ đã hoàn thành'),
        buildTaskTable(completedTasks, 'Chưa có nhiệm vụ hoàn thành.'),
        wHeading('Nhiệm vụ chưa hoàn thành'),
        buildTaskTable(incompleteTasks, 'Không còn nhiệm vụ chưa hoàn thành.')
    ].join('');

    const cover = wTable([
        `<w:tr>${wCell(body, { width: 9400, fill: 'FFFFFF', noBorder: true })}</w:tr>`
    ], [9400], { noBorder: true });

    const documentXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:tbl><w:tblPr><w:tblW w:w="9400" w:type="dxa"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w="9400"/></w:tblGrid><w:tr>${wCell(wParagraph('BÁO CÁO DỰ ÁN', { bold: true, size: 26, color: 'FFFFFF', align: 'center', after: 110 }) + wParagraph(project.name || 'Dự án', { bold: true, size: 18, color: 'FFFFFF', align: 'center', after: 90 }) + wParagraph(`Xuất lúc ${formatDateTime(new Date())}`, { size: 11, color: 'EDE9FE', align: 'center', after: 0 }), { width: 9400, fill: '655CF6', noBorder: true })}</w:tr></w:tbl>
${cover}
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="720" w:right="900" w:bottom="720" w:left="900" w:header="360" w:footer="360" w:gutter="0"/></w:sectPr>
</w:body></w:document>`;

    return buildZip([
        { name: '[Content_Types].xml', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>' },
        { name: '_rels/.rels', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>' },
        { name: 'word/document.xml', data: documentXml },
        { name: 'word/_rels/document.xml.rels', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>' }
    ]);
}

async function getProjectById(projectId, userId, connection = pool) {
    const [rows] = await connection.query(
        `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                p.status, p.start_date, p.end_date,
                p.completed_at, p.completed_by, completed_user.name AS completed_by_name,
                p.created_at, p.updated_at,
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
         LEFT JOIN users completed_user ON completed_user.id = p.completed_by
         LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
         LEFT JOIN tasks t ON t.project_id = p.id
         WHERE p.id = ?
         GROUP BY p.id, p.name, p.description, p.owner_id, owner.name,
                  p.status, p.start_date, p.end_date,
                  p.completed_at, p.completed_by, completed_user.name,
                  p.created_at, p.updated_at,
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
                    p.status, p.start_date, p.end_date,
                    p.completed_at, p.completed_by, completed_user.name AS completed_by_name,
                    p.created_at, p.updated_at,
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
             LEFT JOIN users completed_user ON completed_user.id = p.completed_by
             LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
             LEFT JOIN tasks t ON t.project_id = p.id
             WHERE COALESCE(p.status, 'planning') <> 'completed'
             GROUP BY p.id, p.name, p.description, p.owner_id, owner.name,
                      p.status, p.start_date, p.end_date,
                      p.completed_at, p.completed_by, completed_user.name,
                      p.created_at, p.updated_at,
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

// PATCH /api/projects/:id/complete
// Chỉ trưởng nhóm mới được đánh dấu hoàn thành dự án.
router.patch('/:id/complete', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const canComplete = await isProjectLeader(projectId, userId);
        if (!canComplete) {
            return res.status(403).json({
                success: false,
                message: 'Chỉ trưởng nhóm mới được hoàn thành dự án.'
            });
        }

        const [result] = await pool.query(
            `UPDATE projects
             SET status = 'completed',
                 completed_at = NOW(),
                 completed_by = ?
             WHERE id = ?`,
            [userId, projectId]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án.'
            });
        }

        const project = await getProjectById(projectId, userId);
        return res.json({
            success: true,
            message: 'Dự án đã được đánh dấu hoàn thành.',
            data: project
        });
    } catch (err) {
        console.error('Lỗi hoàn thành dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể hoàn thành dự án.',
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

// GET /api/projects/completed
// Danh sách dự án đã hoàn thành mà user từng tham gia.
router.get('/completed', async (req, res) => {
    try {
        const userId = req.user.id;
        const sort = req.query.sort === 'asc' ? 'ASC' : 'DESC';

        const [rows] = await pool.query(
            `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                    p.status, p.start_date, p.end_date,
                    p.completed_at, p.completed_by, completed_user.name AS completed_by_name,
                    p.created_at, p.updated_at,
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
             LEFT JOIN users completed_user ON completed_user.id = p.completed_by
             LEFT JOIN project_members all_pm ON all_pm.project_id = p.id
             LEFT JOIN tasks t ON t.project_id = p.id
             WHERE p.status = 'completed'
             GROUP BY p.id, p.name, p.description, p.owner_id, owner.name,
                      p.status, p.start_date, p.end_date,
                      p.completed_at, p.completed_by, completed_user.name,
                      p.created_at, p.updated_at,
                      pm.project_role_id, pr.name
             ORDER BY COALESCE(p.completed_at, p.updated_at) ${sort}, p.name ASC`,
            [userId]
        );

        return res.json({
            success: true,
            data: rows.map(mapProject)
        });
    } catch (err) {
        console.error('Lỗi lấy dự án đã hoàn thành:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể lấy dự án đã hoàn thành.',
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

// GET /api/projects/:id/report
// Xuất báo cáo Word cho dự án mà user đang tham gia.
router.get('/:id/report', async (req, res) => {
    try {
        const userId = req.user.id;
        const projectId = Number(req.params.id);

        if (!projectId) {
            return res.status(400).json({
                success: false,
                message: 'ID dự án không hợp lệ.'
            });
        }

        const [projectRows] = await pool.query(
            `SELECT p.id, p.name, p.description, p.owner_id, owner.name AS owner_name,
                    p.status, p.start_date, p.end_date,
                    p.completed_at, p.completed_by, completed_user.name AS completed_by_name,
                    p.created_at, p.updated_at
             FROM projects p
             INNER JOIN project_members current_member
                     ON current_member.project_id = p.id AND current_member.user_id = ?
             LEFT JOIN users owner ON owner.id = p.owner_id
             LEFT JOIN users completed_user ON completed_user.id = p.completed_by
             WHERE p.id = ?
             LIMIT 1`,
            [userId, projectId]
        );

        const project = projectRows[0];
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Không tìm thấy dự án hoặc bạn không có quyền xem.'
            });
        }

        const [members] = await pool.query(
            `SELECT u.id, u.name, u.email, pm.project_role_id, pr.name AS role_name, pm.joined_at
             FROM project_members pm
             INNER JOIN users u ON u.id = pm.user_id
             LEFT JOIN project_roles pr ON pr.id = pm.project_role_id
             WHERE pm.project_id = ?
             ORDER BY
                CASE pm.project_role_id WHEN 1 THEN 0 WHEN 2 THEN 1 ELSE 2 END,
                u.name ASC`,
            [projectId]
        );

        const [tasks] = await pool.query(
            `SELECT t.id, t.title, t.description, t.assignee_id,
                    assignee.name AS assignee_name, assignee.email AS assignee_email,
                    t.start_date, t.due_date, t.status, t.created_at, t.updated_at
             FROM tasks t
             LEFT JOIN users assignee ON assignee.id = t.assignee_id
             WHERE t.project_id = ?
             ORDER BY
                CASE WHEN t.status = 'done' THEN 1 ELSE 0 END,
                CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END,
                t.due_date ASC,
                t.title ASC`,
            [projectId]
        );

        const docx = buildProjectReportDocxBuffer({ project, members, tasks });
        const safeName = String(project.name || 'du-an')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^a-zA-Z0-9_-]+/g, '-')
            .replace(/^-+|-+$/g, '')
            .toLowerCase() || 'du-an';

        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
        res.setHeader('Content-Disposition', `attachment; filename="bao-cao-${safeName}.docx"`);
        return res.send(docx);
    } catch (err) {
        console.error('Lỗi xuất báo cáo dự án:', err);
        return res.status(500).json({
            success: false,
            message: 'Không thể xuất báo cáo dự án.',
            error: err.message
        });
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

                const notificationContent = `Bạn được mời tham gia dự án ${name}.`;
                await connection.query(
                    `INSERT INTO notifications (user_id, type, content, data)
                     VALUES (?, ?, ?, ?)`,
                    [
                        user.id,
                        'project_invitation',
                        notificationContent,
                        JSON.stringify({ invitation_id: invitationResult.insertId, project_id: projectId })
                    ]
                );
                sendPushToUser(user.id, {
                    title: 'Lời mời dự án',
                    body: notificationContent,
                    data: {
                        type: 'project_invitation',
                        invitation_id: invitationResult.insertId,
                        project_id: projectId
                    }
                }).catch((err) => console.warn('Khong the gui push notification:', err.message));
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
