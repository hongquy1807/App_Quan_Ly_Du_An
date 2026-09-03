(() => {
  const TOKEN_KEY = "quanlyduan_admin_token";
  const USER_KEY = "quanlyduan_admin_user";
  const API_BASE_URL = window.location.protocol === "file:"
    ? "http://localhost:3000/api"
    : `${window.location.origin}/api`;
  const ADMIN_API_URL = `${API_BASE_URL}/admin`;

  const statusLabels = {
    planning: "Lên kế hoạch",
    in_progress: "Đang thực hiện",
    completed: "Hoàn thành",
    paused: "Tạm dừng",
    todo: "Chưa nhận",
    review: "Chờ duyệt",
    done: "Hoàn thành",
  };

  function clearSession() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  function getAdminUser() {
    const token = localStorage.getItem(TOKEN_KEY);
    const rawUser = localStorage.getItem(USER_KEY);
    if (!token || !rawUser) {
      window.location.replace("./login.html");
      return null;
    }
    try {
      return JSON.parse(rawUser);
    } catch (_) {
      clearSession();
      window.location.replace("./login.html");
      return null;
    }
  }

  const currentAdmin = getAdminUser();
  if (!currentAdmin) return;

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatDate(value) {
    if (!value) return "--";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat("vi-VN", { day: "2-digit", month: "2-digit", year: "numeric" }).format(date);
  }

  function statusLabel(value) {
    return statusLabels[value] || value || "--";
  }

  function taskStatusTone(value) {
    if (value === "done") return "status-resolved";
    if (value === "review") return "status-reviewing";
    if (value === "in_progress") return "";
    return "status-pending";
  }

  async function apiRequest(path) {
    let response;
    try {
      response = await fetch(`${ADMIN_API_URL}${path}`, {
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${localStorage.getItem(TOKEN_KEY) || ""}`,
        },
      });
    } catch (_) {
      throw new Error("Không thể kết nối máy chủ API.");
    }
    const data = await response.json().catch(() => ({}));
    if (response.status === 401) {
      clearSession();
      window.location.replace("./login.html");
      throw new Error("Phiên đăng nhập đã hết hạn.");
    }
    if (!response.ok || !data.success) throw new Error(data.message || "API xử lý thất bại.");
    return data;
  }

  function renderAdmin() {
    const name = currentAdmin.name || currentAdmin.email || "Admin";
    document.getElementById("adminName").textContent = name;
    document.getElementById("adminAvatar").textContent = name.trim().charAt(0).toUpperCase() || "A";
  }

  function renderProject(data) {
    const project = data.project || {};
    const summary = data.task_summary || {};
    const tasks = Array.isArray(data.tasks) ? data.tasks : [];
    const members = Array.isArray(data.members) ? data.members : [];
    const doneCount = Number(summary.done ?? tasks.filter((task) => task.status === "done").length);
    const totalCount = Number(summary.total ?? tasks.length);

    document.title = `${project.name || "Chi tiết dự án"} - QuanLyDuAn Admin`;
    document.getElementById("projectTitle").textContent = project.name || "Chi tiết dự án";
    document.getElementById("projectName").textContent = project.name || "Không tên";
    document.getElementById("projectDescription").textContent = project.description || "Dự án chưa có mô tả.";
    document.getElementById("projectStatus").textContent = statusLabel(project.status);
    const memberCount = Number(project.members_count ?? members.length);
    const taskCount = Number(project.tasks_count ?? totalCount);
    const completedTaskCount = Number(project.completed_tasks_count ?? doneCount);
    document.getElementById("memberCount").textContent = String(memberCount);
    document.getElementById("taskCount").textContent = String(taskCount);
    document.getElementById("doneTaskCount").textContent = String(completedTaskCount);
    document.getElementById("openTaskCount").textContent = String(Math.max(0, taskCount - completedTaskCount));
    renderTasks(tasks);
    renderMembers(members);
  }

  function renderTasks(tasks) {
    const list = document.getElementById("taskList");
    if (!tasks.length) {
      list.innerHTML = `<div class="empty-detail">Dự án này chưa có task.</div>`;
      return;
    }
    list.innerHTML = tasks.map((task) => `
      <article class="task-card">
        <div class="task-main">
          <strong>${escapeHtml(task.title || "Không tên task")}</strong>
          <p>${escapeHtml(task.description || "Không có mô tả.")}</p>
          <div class="task-meta">
            <span>Người thực hiện: ${escapeHtml(task.assignee_name || "Cả team")}</span>
            <span>Hạn chót: ${escapeHtml(formatDate(task.due_date))}</span>
          </div>
        </div>
        <span class="status-pill ${taskStatusTone(task.status)}">${escapeHtml(statusLabel(task.status))}</span>
      </article>
    `).join("");
  }

  function renderMembers(members) {
    const list = document.getElementById("memberList");
    if (!members.length) {
      list.innerHTML = `<div class="empty-detail">Dự án này chưa có thành viên.</div>`;
      return;
    }
    list.innerHTML = members.map((member) => `
      <article class="member-card">
        <div class="mini-avatar">${escapeHtml((member.name || member.email || "?").charAt(0).toUpperCase())}</div>
        <div>
          <strong>${escapeHtml(member.name || "Không tên")}</strong>
          <span>${escapeHtml(member.email || "")}</span>
        </div>
        <span class="role-pill">${escapeHtml(member.role_name || "Thành viên")}</span>
      </article>
    `).join("");
  }

  function renderError(message) {
    document.getElementById("projectName").textContent = "Không thể tải dự án";
    document.getElementById("projectDescription").textContent = message;
    document.getElementById("taskList").innerHTML = `<div class="empty-detail">${escapeHtml(message)}</div>`;
    document.getElementById("memberList").innerHTML = `<div class="empty-detail">${escapeHtml(message)}</div>`;
  }

  async function init() {
    renderAdmin();
    document.getElementById("logoutBtn")?.addEventListener("click", () => {
      clearSession();
      window.location.replace("./login.html");
    });
    const id = Number(new URLSearchParams(window.location.search).get("id"));
    if (!id) {
      renderError("ID dự án không hợp lệ.");
      return;
    }
    try {
      const response = await apiRequest(`/projects/${id}`);
      renderProject(response.data || {});
    } catch (error) {
      renderError(error.message || "Không thể tải chi tiết dự án.");
    }
  }

  void init();
})();
