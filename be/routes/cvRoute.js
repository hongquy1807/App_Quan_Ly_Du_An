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
  queueLimit: 0,
});

const JWT_SECRET = process.env.JWT_SECRET || 'quanlyduan-dev-secret';
let cvTableReady = false;

function getBearerToken(req) {
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) return null;
  return authHeader.slice(7).trim();
}

function requireAuth(req, res, next) {
  try {
    const token = getBearerToken(req);
    if (!token) {
      return res.status(401).json({ success: false, message: 'Bạn chưa đăng nhập.' });
    }
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
    });
  }
}

async function ensureCvTable() {
  if (cvTableReady) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS electronic_cvs (
      id INT NOT NULL AUTO_INCREMENT,
      user_id INT NOT NULL,
      title VARCHAR(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      objective TEXT COLLATE utf8mb4_unicode_ci,
      education TEXT COLLATE utf8mb4_unicode_ci,
      skills TEXT COLLATE utf8mb4_unicode_ci,
      soft_skills TEXT COLLATE utf8mb4_unicode_ci,
      languages TEXT COLLATE utf8mb4_unicode_ci,
      projects TEXT COLLATE utf8mb4_unicode_ci,
      certificates TEXT COLLATE utf8mb4_unicode_ci,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_electronic_cvs_user_id (user_id),
      CONSTRAINT electronic_cvs_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
  try {
    await pool.query('ALTER TABLE electronic_cvs ADD COLUMN languages TEXT COLLATE utf8mb4_unicode_ci NULL AFTER soft_skills');
  } catch (err) {
    if (err?.code !== 'ER_DUP_FIELDNAME') throw err;
  }
  cvTableReady = true;
}

function formatDateOnly(value) {
  if (!value) return '';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  return `${day}/${month}/${date.getFullYear()}`;
}

function text(value) {
  return String(value || '').trim();
}

function escapeHtml(value) {
  return text(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}


function escapeXml(value) {
  return text(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
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

function splitLines(value) {
  return text(value)
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function buildProjectsText(projects) {
  if (projects.length === 0) return '';
  return projects
    .map((project) => project.name || '')
    .filter(Boolean)
    .join('\n');
}

async function loadCvData(userId) {
  await ensureCvTable();

  const [[user]] = await pool.query(
    `SELECT id, name, email, avatar, birthday, address, phone
     FROM users
     WHERE id = ?
     LIMIT 1`,
    [userId]
  );

  if (!user) return null;

  const [[cv]] = await pool.query(
    `SELECT title, objective, education, skills, soft_skills, languages, projects, certificates
     FROM electronic_cvs
     WHERE user_id = ?
     LIMIT 1`,
    [userId]
  );

  const [projects] = await pool.query(
    `SELECT p.id, p.name, p.description, p.start_date, p.end_date, p.completed_at
     FROM projects p
     INNER JOIN project_members pm ON pm.project_id = p.id
     WHERE pm.user_id = ? AND COALESCE(p.status, 'planning') = 'completed'
     ORDER BY COALESCE(p.completed_at, p.updated_at, p.created_at) DESC`,
    [userId]
  );

  const [tasks] = await pool.query(
    `SELECT t.id, t.project_id, t.title, t.description, t.status, t.due_date, p.name AS project_name
     FROM tasks t
     INNER JOIN projects p ON p.id = t.project_id
     LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = ?
     WHERE COALESCE(p.status, 'planning') = 'completed'
       AND pm.user_id IS NOT NULL
       AND (t.assignee_id = ? OR t.assignee_id IS NULL)
     ORDER BY COALESCE(t.due_date, t.updated_at, t.created_at) DESC`,
    [userId, userId]
  );

  const suggestedProjects = buildProjectsText(projects);
  const cvProjects = cv ? text(cv.projects) : suggestedProjects;

  return {
    profile: {
      id: user.id,
      name: user.name || '',
      email: user.email || '',
      avatar: user.avatar || '',
      phone: user.phone || '',
      birthday: formatDateOnly(user.birthday),
      address: user.address || '',
    },
    cv: {
      title: cv?.title || '',
      objective: cv?.objective || '',
      education: cv?.education || '',
      skills: cv?.skills || '',
      softSkills: cv?.soft_skills || '',
      languages: cv?.languages || '',
      projects: cvProjects,
      certificates: cv?.certificates || '',
    },
    completedProjects: projects.map((project) => ({
      id: project.id,
      name: project.name || '',
      description: project.description || '',
      startDate: formatDateOnly(project.start_date),
      endDate: formatDateOnly(project.end_date),
      completedAt: formatDateOnly(project.completed_at),
    })),
    completedTasks: tasks.map((task) => ({
      id: task.id,
      projectId: task.project_id,
      projectName: task.project_name || '',
      title: task.title || '',
      description: task.description || '',
      status: task.status || '',
      dueDate: formatDateOnly(task.due_date),
    })),
  };
}

function normalizeCvPayload(body) {
  return {
    title: text(body?.title),
    objective: text(body?.objective),
    education: text(body?.education),
    skills: text(body?.skills),
    softSkills: text(body?.softSkills ?? body?.soft_skills),
    languages: text(body?.languages),
    projects: text(body?.projects),
    certificates: text(body?.certificates),
  };
}

function getAvatarDataUri(avatarPath) {
  const avatar = text(avatarPath);
  if (!avatar || avatar.startsWith('http://') || avatar.startsWith('https://')) return '';

  const cleanPath = avatar.replace(/^\/+/, '');
  const filePath = path.join(__dirname, '..', cleanPath);
  const resolvedUploadRoot = path.resolve(__dirname, '..', 'upload');
  const resolvedFilePath = path.resolve(filePath);
  if (!resolvedFilePath.startsWith(resolvedUploadRoot) || !fs.existsSync(resolvedFilePath)) {
    return '';
  }

  const ext = path.extname(resolvedFilePath).toLowerCase();
  const mime = ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg';
  const base64 = fs.readFileSync(resolvedFilePath).toString('base64');
  return `data:${mime};base64,${base64}`;
}

function buildAvatarBlock(profile) {
  const avatarDataUri = getAvatarDataUri(profile.avatar);
  if (avatarDataUri) {
    return `<img class="avatar" src="${avatarDataUri}" alt="Avatar">`;
  }

  const letter = escapeHtml((profile.name || 'C').trim().charAt(0).toUpperCase() || 'C');
  return `<div class="avatar avatar-letter">${letter}</div>`;
}

function buildCvHtml(data) {
  const profile = data.profile;
  const cv = data.cv;
  const contactItems = [
    ['Email', profile.email],
    ['?i?n tho?i', profile.phone],
    ['Ng?y sinh', profile.birthday],
    ['??a ch?', profile.address],
  ].filter((item) => text(item[1]));

  const section = (title, value, chips = false) => {
    const lines = splitLines(value);
    if (lines.length === 0) return '';
    if (chips) {
      return `<section><h2>${escapeHtml(title)}</h2><div class="chips">${lines
        .map((line) => `<span class="chip">${escapeHtml(line)}</span>`)
        .join('')}</div></section>`;
    }
    return `<section><h2>${escapeHtml(title)}</h2>${lines
      .map((line) => `<p>${escapeHtml(line)}</p>`)
      .join('')}</section>`;
  };

  const projectList = splitLines(cv.projects)
    .map((project) => `<li>${escapeHtml(project)}</li>`)
    .join('');

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CV ${escapeHtml(profile.name)}</title>
<style>
  @page { margin: 22mm 18mm; }
  body {
    margin: 0;
    font-family: Arial, Helvetica, sans-serif;
    color: #1f2937;
    background: #ffffff;
    line-height: 1.45;
  }
  .cv-page {
    width: 100%;
    border: 1px solid #e5e7eb;
  }
  .hero {
    background: #655cf6;
    color: #ffffff;
    padding: 30px 34px;
  }
  .hero-table { width: 100%; border-collapse: collapse; }
  .avatar-cell { width: 122px; vertical-align: middle; }
  .avatar {
    width: 104px;
    height: 104px;
    border-radius: 52px;
    object-fit: cover;
    border: 5px solid rgba(255,255,255,0.92);
    background: #ffffff;
  }
  .avatar-letter {
    line-height: 104px;
    text-align: center;
    color: #655cf6;
    font-size: 44px;
    font-weight: 800;
  }
  h1 {
    margin: 0;
    font-size: 34px;
    line-height: 1.15;
    letter-spacing: 0;
  }
  .job-title {
    margin-top: 8px;
    font-size: 16px;
    font-weight: 700;
    opacity: 0.95;
  }
  .body-table { width: 100%; border-collapse: collapse; }
  .sidebar {
    width: 32%;
    background: #f5f3ff;
    vertical-align: top;
    padding: 26px 22px;
  }
  .main {
    width: 68%;
    vertical-align: top;
    padding: 26px 28px;
  }
  h2 {
    margin: 0 0 12px;
    color: #4f46e5;
    font-size: 15px;
    text-transform: uppercase;
    border-bottom: 2px solid #ddd6fe;
    padding-bottom: 7px;
  }
  section { margin-bottom: 22px; }
  p { margin: 0 0 8px; font-size: 13.5px; }
  .contact-item { margin-bottom: 13px; }
  .contact-label {
    color: #6d28d9;
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
  }
  .contact-value {
    margin-top: 3px;
    font-size: 13px;
    font-weight: 700;
    color: #1f2937;
    word-break: break-word;
  }
  .chip {
    display: inline-block;
    margin: 0 6px 7px 0;
    padding: 7px 10px;
    border-radius: 9px;
    background: #ede9fe;
    color: #4f46e5;
    font-size: 12px;
    font-weight: 800;
  }
  ul.projects { margin: 0; padding-left: 18px; }
  ul.projects li { margin-bottom: 8px; font-weight: 700; }
  .empty-note { color: #9ca3af; font-style: italic; }
</style>
</head>
<body>
  <div class="cv-page">
    <div class="hero">
      <table class="hero-table">
        <tr>
          <td class="avatar-cell">${buildAvatarBlock(profile)}</td>
          <td>
            <h1>${escapeHtml(profile.name || 'H? t?n')}</h1>
            <div class="job-title">${escapeHtml(cv.title || 'V? tr? ?ng tuy?n')}</div>
          </td>
        </tr>
      </table>
    </div>
    <table class="body-table">
      <tr>
        <td class="sidebar">
          <section>
            <h2>Th?ng tin</h2>
            ${contactItems.map((item) => `<div class="contact-item"><div class="contact-label">${escapeHtml(item[0])}</div><div class="contact-value">${escapeHtml(item[1])}</div></div>`).join('')}
          </section>
          ${section('K? n?ng chuy?n m?n', cv.skills, true)}
          ${section('K? n?ng m?m', cv.softSkills, true)}
          ${section('Ngoại ngữ', cv.languages, true)}
        </td>
        <td class="main">
          ${section('M?c ti?u ngh? nghi?p', cv.objective)}
          ${section('H?c v?n', cv.education)}
          <section>
            <h2>D? ?n ?? ho?n th?nh</h2>
            ${projectList ? `<ul class="projects">${projectList}</ul>` : '<p class="empty-note">Ch?a c? d? ?n ho?n th?nh.</p>'}
          </section>
          ${section('Ch?ng ch? / ho?t ??ng / s? th?ch', cv.certificates)}
        </td>
      </tr>
    </table>
  </div>
</body>
</html>`;
}


function getAvatarFileForDocx(avatarPath) {
  const avatar = text(avatarPath);
  if (!avatar || avatar.startsWith('http://') || avatar.startsWith('https://')) return null;
  const cleanPath = avatar.replace(/^\/+/, '');
  const filePath = path.resolve(path.join(__dirname, '..', cleanPath));
  const uploadRoot = path.resolve(__dirname, '..', 'upload');
  if (!filePath.startsWith(uploadRoot) || !fs.existsSync(filePath)) return null;
  const ext = path.extname(filePath).toLowerCase();
  const contentType = ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg';
  const docxExt = ext === '.png' ? 'png' : ext === '.webp' ? 'webp' : 'jpg';
  const data = fs.readFileSync(filePath);
  return { data, contentType, docxExt, orientation: getJpegOrientation(data) };
}

function getJpegOrientation(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4 || buffer.readUInt16BE(0) !== 0xffd8) return 1;

  let offset = 2;
  while (offset + 4 < buffer.length) {
    if (buffer[offset] !== 0xff) return 1;
    const marker = buffer[offset + 1];
    const size = buffer.readUInt16BE(offset + 2);
    if (size < 2 || offset + 2 + size > buffer.length) return 1;

    if (marker === 0xe1 && size >= 10) {
      const exif = buffer.subarray(offset + 4, offset + 2 + size);
      if (exif.toString('ascii', 0, 6) !== 'Exif\0\0') return 1;

      const tiff = 6;
      const byteOrder = exif.toString('ascii', tiff, tiff + 2);
      const littleEndian = byteOrder === 'II';
      if (!littleEndian && byteOrder !== 'MM') return 1;

      const read16 = (pos) => (littleEndian ? exif.readUInt16LE(pos) : exif.readUInt16BE(pos));
      const read32 = (pos) => (littleEndian ? exif.readUInt32LE(pos) : exif.readUInt32BE(pos));
      const ifdOffset = read32(tiff + 4);
      const ifd = tiff + ifdOffset;
      if (ifd < 0 || ifd + 2 > exif.length) return 1;

      const entries = read16(ifd);
      for (let i = 0; i < entries; i += 1) {
        const entry = ifd + 2 + i * 12;
        if (entry + 12 > exif.length) return 1;
        if (read16(entry) === 0x0112) return read16(entry + 8);
      }
    }

    offset += 2 + size;
  }

  return 1;
}

function wText(value) {
  return `<w:t xml:space="preserve">${escapeXml(value)}</w:t>`;
}

function wRun(value, opts = {}) {
  const color = opts.color ? `<w:color w:val="${opts.color}"/>` : '';
  const bold = opts.bold ? '<w:b/><w:bCs/>' : '';
  const italic = opts.italic ? '<w:i/><w:iCs/>' : '';
  const size = opts.size ? `<w:sz w:val="${opts.size * 2}"/><w:szCs w:val="${opts.size * 2}"/>` : '';
  return `<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>${bold}${italic}${color}${size}</w:rPr>${wText(value)}</w:r>`;
}

function wParagraph(value, opts = {}) {
  const align = opts.align ? `<w:jc w:val="${opts.align}"/>` : '';
  const spacing = `<w:spacing w:before="${opts.before || 0}" w:after="${opts.after ?? 90}"/>`;
  return `<w:p><w:pPr>${align}${spacing}</w:pPr>${wRun(value, opts)}</w:p>`;
}

function wHeading(value, color = '00AEEF') {
  return `<w:p><w:pPr><w:spacing w:before="180" w:after="90"/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="2" w:color="${color}"/></w:pBdr></w:pPr>${wRun(value.toUpperCase(), { bold: true, size: 13, color })}</w:p>`;
}

function wBullets(value, opts = {}) {
  const lines = splitLines(value);
  if (lines.length === 0) return wParagraph(opts.empty || '', { size: 10, color: '777777' });
  return lines.map((line) => wParagraph(`- ${line}`, { size: opts.size || 10.5, color: opts.color || '333333', after: 60 })).join('');
}

function wContact(label, value) {
  if (!text(value)) return '';
  return `<w:p><w:pPr><w:spacing w:after="80"/></w:pPr>${wRun(label + ': ', { bold: true, size: 9.5, color: '00AEEF' })}${wRun(value, { size: 9.5, color: 'FFFFFF' })}</w:p>`;
}

function wCell(content, opts = {}) {
  const width = opts.width || 4500;
  const fill = opts.fill ? `<w:shd w:val="clear" w:color="auto" w:fill="${opts.fill}"/>` : '';
  const vAlign = opts.vAlign ? `<w:vAlign w:val="${opts.vAlign}"/>` : '';
  const margins = '<w:tcMar><w:top w:w="160" w:type="dxa"/><w:left w:w="180" w:type="dxa"/><w:bottom w:w="160" w:type="dxa"/><w:right w:w="180" w:type="dxa"/></w:tcMar>';
  return `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/>${fill}${vAlign}${margins}</w:tcPr>${content || '<w:p/>'}</w:tc>`;
}

function wTable(rows, widths) {
  const grid = widths.map((w) => `<w:gridCol w:w="${w}"/>`).join('');
  return `<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr><w:tblGrid>${grid}</w:tblGrid>${rows.join('')}</w:tbl>`;
}

function avatarRotation(orientation) {
  if (orientation === 3) return 10800000;
  if (orientation === 6) return 5400000;
  if (orientation === 8) return 16200000;
  return 0;
}

function avatarDrawingXml(avatar) {
  const rotation = avatarRotation(avatar?.orientation);
  const xfrmAttrs = rotation ? ` rot="${rotation}"` : '';
  return `<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="160"/></w:pPr><w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0"><wp:extent cx="1280000" cy="1280000"/><wp:docPr id="1" name="Avatar"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="1" name="avatar"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdAvatar" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm${xfrmAttrs}><a:off x="0" y="0"/><a:ext cx="1280000" cy="1280000"/></a:xfrm><a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>`;
}

function avatarLetterXml(profile) {
  const letter = (profile.name || 'C').trim().charAt(0).toUpperCase() || 'C';
  return `<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="160"/></w:pPr>${wRun(letter, { bold: true, size: 36, color: 'FFFFFF' })}</w:p>`;
}

function wInfoPill(label, value) {
  if (!text(value)) return '';
  return `<w:p><w:pPr><w:spacing w:after="80"/></w:pPr>${wRun(`${label}: `, { bold: true, size: 9.5, color: '655CF6' })}${wRun(value, { size: 9.5, color: '1F2937', bold: true })}</w:p>`;
}

function wChip(value) {
  if (!text(value)) return '';
  return `<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:b/><w:color w:val="655CF6"/><w:sz w:val="20"/><w:szCs w:val="20"/><w:shd w:val="clear" w:color="auto" w:fill="EFECFF"/></w:rPr>${wText(`  ${value}  `)}</w:r><w:r><w:t xml:space="preserve">  </w:t></w:r>`;
}

function wChipParagraph(value) {
  const chips = splitLines(value);
  if (chips.length === 0) return wParagraph('Ch?a c?p nh?t', { size: 10, color: '9CA3AF' });
  return `<w:p><w:pPr><w:spacing w:after="120"/></w:pPr>${chips.map(wChip).join('')}</w:p>`;
}

function wPlainLines(value, empty = 'Ch?a c?p nh?t') {
  const lines = splitLines(value);
  if (lines.length === 0) return wParagraph(empty, { size: 10.5, color: '9CA3AF', after: 120 });
  return lines.map((line) => wParagraph(line, { size: 10.5, color: '1F2937', after: 70 })).join('');
}

function buildDocxDocumentXml(data, avatar) {
  const profile = data.profile;
  const cv = data.cv;
  const hasAvatar = Boolean(avatar);

  const hero = [
    hasAvatar ? avatarDrawingXml(avatar) : avatarLetterXml(profile),
    wParagraph(profile.name || 'H? t?n', { bold: true, size: 24, color: 'FFFFFF', align: 'center', after: 80 }),
    wParagraph(cv.title || 'V? tr? ?ng tuy?n', { bold: true, size: 12, color: 'FFFFFF', align: 'center', after: 120 }),
  ].join('');

  const contact = wTable([
    `<w:tr>${wCell(wInfoPill('Email', profile.email), { width: 4700, fill: 'FFFFFF' })}${wCell(wInfoPill('SĐT', profile.phone), { width: 4700, fill: 'FFFFFF' })}</w:tr>`,
    `<w:tr>${wCell(wInfoPill('Ngày sinh', profile.birthday), { width: 4700, fill: 'FFFFFF' })}${wCell(wInfoPill('Địa chỉ', profile.address), { width: 4700, fill: 'FFFFFF' })}</w:tr>`,
  ], [4700, 4700]);

  const content = [
    contact,
    wHeading('Mục tiêu nghề nghiệp', '655CF6'),
    wPlainLines(cv.objective, 'Chưa cập nhật mục tiêu nghề nghiệp.'),
    wHeading('Học vấn', '655CF6'),
    wPlainLines(cv.education, 'Chưa cập nhật học vấn.'),
    wHeading('Kỹ năng chuyên môn', '655CF6'),
    wChipParagraph(cv.skills),
    wHeading('Kỹ năng mềm', '655CF6'),
    wChipParagraph(cv.softSkills),
    wHeading('Ngoại ngữ', '655CF6'),
    wChipParagraph(cv.languages),
    wHeading('Dự án / kinh nghiệm', '655CF6'),
    wPlainLines(cv.projects, 'Chưa có dự án hoàn thành.'),
    wHeading('Chứng chỉ / hoạt động / sở thích', '655CF6'),
    wPlainLines(cv.certificates, 'Chưa cập nhật.'),
  ].join('');

  const page = wTable([
    `<w:tr>${wCell(hero, { width: 9400, fill: '655CF6', vAlign: 'center' })}</w:tr>`,
    `<w:tr>${wCell(content, { width: 9400, fill: 'FFFFFF', vAlign: 'top' })}</w:tr>`,
  ], [9400]);

  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
<w:body>${page}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="720" w:right="900" w:bottom="720" w:left="900" w:header="360" w:footer="360" w:gutter="0"/></w:sectPr></w:body></w:document>`;
}

function buildCvDocxBuffer(data) {
  const avatar = getAvatarFileForDocx(data.profile.avatar);
  const files = [
    { name: '[Content_Types].xml', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>${avatar ? `<Default Extension="${avatar.docxExt}" ContentType="${avatar.contentType}"/>` : ''}<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>` },
    { name: '_rels/.rels', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>` },
    { name: 'word/document.xml', data: buildDocxDocumentXml(data, avatar) },
    { name: 'word/_rels/document.xml.rels', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${avatar ? `<Relationship Id="rIdAvatar" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/avatar.${avatar.docxExt}"/>` : ''}</Relationships>` },
  ];
  if (avatar) files.push({ name: `word/media/avatar.${avatar.docxExt}`, data: avatar.data });
  return buildZip(files);
}

function sanitizeFileName(value) {
  const base = text(value) || 'cv';
  return base.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-zA-Z0-9_-]+/g, '_').replace(/^_+|_+$/g, '') || 'cv';
}

router.use(requireAuth);

router.get('/', async (req, res) => {
  try {
    const data = await loadCvData(req.user.id);
    if (!data) return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản.' });
    return res.json({ success: true, data });
  } catch (err) {
    console.error('CV API error:', err);
    return res.status(500).json({ success: false, message: 'Không thể tải dữ liệu CV.' });
  }
});

router.put('/', async (req, res) => {
  try {
    await ensureCvTable();
    const cv = normalizeCvPayload(req.body);
    await pool.query(
      `INSERT INTO electronic_cvs (user_id, title, objective, education, skills, soft_skills, languages, projects, certificates)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         title = VALUES(title), objective = VALUES(objective), education = VALUES(education),
         skills = VALUES(skills), soft_skills = VALUES(soft_skills), languages = VALUES(languages), projects = VALUES(projects),
         certificates = VALUES(certificates), updated_at = CURRENT_TIMESTAMP`,
      [req.user.id, cv.title, cv.objective, cv.education, cv.skills, cv.softSkills, cv.languages, cv.projects, cv.certificates]
    );
    const data = await loadCvData(req.user.id);
    return res.json({ success: true, message: 'Đã lưu CV điện tử.', data });
  } catch (err) {
    console.error('Save CV API error:', err);
    return res.status(500).json({ success: false, message: 'Không thể lưu CV điện tử.' });
  }
});

router.get('/export/:type', async (req, res) => {
  try {
    const data = await loadCvData(req.user.id);
    if (!data) return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản.' });

    const type = String(req.params.type || '').toLowerCase();
    const fileBase = `CV_${sanitizeFileName(data.profile.name)}`;

    if (type === 'word' || type === 'doc' || type === 'docx') {
      const docx = buildCvDocxBuffer(data);
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.docx"`);
      return res.send(docx);
    }

    return res.status(400).json({
      success: false,
      message: 'Định dạng xuất chưa được hỗ trợ. Hiện chỉ hỗ trợ Word.',
    });
  } catch (err) {
    console.error('Export CV API error:', err);
    return res.status(500).json({ success: false, message: 'Không thể xuất CV.' });
  }
});

module.exports = router;
