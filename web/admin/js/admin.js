(() => {
  const TOKEN_KEY = "quanlyduan_admin_token";
  const USER_KEY = "quanlyduan_admin_user";
  const API_BASE_URL = window.location.protocol === "file:"
    ? "http://localhost:3000/api"
    : `${window.location.origin}/api`;
  const ADMIN_API_URL = `${API_BASE_URL}/admin`;

  const pageTitles = {
    overview: "Tổng quan hệ thống",
    users: "Quản lý người dùng",
    projects: "Quản lý dự án",
    feedbacks: "Quản lý thư góp ý",
  };

  const projectStatusLabels = {
    planning: "Lên kế hoạch",
    in_progress: "Đang thực hiện",
    completed: "Hoàn thành",
    paused: "Tạm dừng",
  };

  const projectStatusCodes = Object.fromEntries(
    Object.entries(projectStatusLabels).map(([code, label]) => [label, code])
  );

  const userStatusLabels = {
    active: "Hoạt động",
    suspended: "Tạm khóa",
  };

  const userStatusCodes = Object.fromEntries(
    Object.entries(userStatusLabels).map(([code, label]) => [label, code])
  );

  const state = {
    activeSection: "overview",
    currentAdmin: null,
    systemRoles: [
      { id: 1, name: "Admin" },
      { id: 2, name: "Member" },
    ],
    stats: { total_projects: 0, total_users: 0, total_feedbacks: 0, pending_feedbacks: 0 },
    users: [],
    projects: [],
    feedbacks: [],
    userPage: 1,
    usersPerPage: 20,
    userSearch: "",
    userPagination: null,
    projectPage: 1,
    projectsPerPage: 20,
    projectSearch: "",
    projectPagination: null,
    feedbackPage: 1,
    feedbacksPerPage: 20,
    feedbackSearch: "",
    feedbackStatusFilter: "all",
    feedbackPagination: null,
    selectedFeedbackId: null,
    isLoading: false,
  };

  function isAdminUser(user) {
    const roleName = String(user?.role_name || user?.role?.name || "").trim().toLowerCase();
    return Number(user?.system_role_id || user?.role_id) === 1 ||
      ["admin", "administrator", "quan tri vien", "quản trị viên"].includes(roleName);
  }

  function clearSession() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  function requireAdminSession() {
    const token = localStorage.getItem(TOKEN_KEY);
    const rawUser = localStorage.getItem(USER_KEY);
    if (!token || !rawUser) {
      window.location.replace("./login.html");
      return null;
    }

    try {
      const user = JSON.parse(rawUser);
      if (!isAdminUser(user)) throw new Error("Not admin");
      return user;
    } catch (_) {
      clearSession();
      window.location.replace("./login.html");
      return null;
    }
  }

  const currentAdmin = requireAdminSession();
  if (!currentAdmin) return;
  state.currentAdmin = currentAdmin;

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat("vi-VN", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    }).format(date);
  }

  function formatRelativeDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    const diffMinutes = Math.round((Date.now() - date.getTime()) / 60000);
    if (diffMinutes < 1) return "Vừa xong";
    if (diffMinutes < 60) return `${diffMinutes} phút trước`;
    if (diffMinutes < 1440) return `${Math.floor(diffMinutes / 60)} giờ trước`;
    if (diffMinutes < 2880) return "Hôm qua";
    return formatDate(value);
  }

  function normalizeUserStatus(value) {
    return userStatusCodes[value] || value || "active";
  }

  function normalizeProjectStatus(value) {
    return projectStatusCodes[value] || value || "planning";
  }

  function renderUserRoleOptions(selectedValue = null) {
    const select = document.getElementById("userRoleInput");
    if (!select) return;
    const roles = state.systemRoles.length
      ? state.systemRoles
      : [
          { id: 1, name: "Admin" },
          { id: 2, name: "Member" },
        ];
    select.innerHTML = roles
      .map((role) => `<option value="${Number(role.id)}">${escapeHtml(role.name)}</option>`)
      .join("");
    if (selectedValue !== null && roles.some((role) => String(role.id) === String(selectedValue))) {
      select.value = String(selectedValue);
    }
  }

  function statusLabel(value) {
    return projectStatusLabels[value] || value || "—";
  }

  function feedbackStatusLabel(value) {
    return {
      pending: "Chờ xử lý",
      reviewing: "Đang xem xét",
      resolved: "Đã xử lý",
      rejected: "Từ chối",
    }[value] || value || "—";
  }

  function attachmentLabel(type) {
    return { image: "Ảnh", video: "Video", document: "Tài liệu" }[type] || "File";
  }

  function mapUser(user) {
    const role = user.role || {};
    const roleId = Number(user.role_id || role.id || user.system_role_id || 0) || null;
    const roleName = user.role_name || role.name || (roleId === 1 ? "Admin" : "Member");
    const status = userStatusLabels[user.status] ? user.status : normalizeUserStatus(user.status);
    return {
      ...user,
      id: Number(user.id),
      name: user.name || user.email || "Không tên",
      email: user.email || "",
      role_id: roleId,
      role_name: roleName,
      role: roleName,
      status,
      joinedAt: formatDate(user.created_at || user.joinedAt),
    };
  }

  function mapProject(project) {
    const owner = project.owner || {};
    const ownerName = project.owner_name || owner.name || project.owner || "Chưa có trưởng nhóm";
    const status = normalizeProjectStatus(project.status);
    return {
      ...project,
      id: Number(project.id),
      name: project.name || "Không tên",
      description: project.description || "",
      owner_id: Number(project.owner_id || owner.id || 0) || null,
      owner: ownerName,
      owner_email: project.owner_email || owner.email || "",
      members: Number(project.members_count ?? project.members ?? 0),
      tasks: Number(project.tasks_count ?? project.totalTasks ?? project.tasks ?? 0),
      completed_tasks: Number(project.completed_tasks_count ?? project.completedTasks ?? 0),
      status,
      createdAt: formatDate(project.created_at || project.createdAt),
    };
  }

  function mapAttachment(attachment) {
    return {
      ...attachment,
      id: Number(attachment.id || 0),
      name: attachment.file_name || attachment.name || "Tệp đính kèm",
      url: attachment.file_url || attachment.url || "#",
      type: attachment.file_type || attachment.type || "document",
    };
  }

  function mapFeedback(feedback) {
    const sender = feedback.sender || {};
    return {
      ...feedback,
      id: Number(feedback.id),
      title: feedback.title || "Không có tiêu đề",
      content: feedback.content || feedback.content_preview || "",
      sender: feedback.user_name || sender.name || feedback.sender || "Tài khoản đã xóa",
      email: feedback.user_email || sender.email || feedback.email || "",
      status: feedback.status || "pending",
      attachments: Array.isArray(feedback.attachments) ? feedback.attachments.map(mapAttachment) : [],
      createdAt: formatDate(feedback.created_at || feedback.createdAt),
    };
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY) || "";
  }

  async function apiRequest(path, options = {}) {
    const headers = {
      Accept: "application/json",
      Authorization: `Bearer ${getToken()}`,
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(options.headers || {}),
    };

    let response;
    try {
      response = await fetch(`${ADMIN_API_URL}${path}`, { ...options, headers });
    } catch (_) {
      throw new Error("Không thể kết nối máy chủ API.");
    }

    const data = await response.json().catch(() => ({}));
    if (response.status === 401) {
      clearSession();
      window.location.replace("./login.html");
      throw new Error("Phiên đăng nhập đã hết hạn.");
    }
    if (!response.ok || !data.success) {
      const validationMessage = data.errors && Object.values(data.errors)[0];
      throw new Error(validationMessage || data.message || "API xử lý thất bại.");
    }
    return data;
  }

  function setStat(id, value) {
    const element = document.getElementById(id);
    if (element) element.textContent = Number(value || 0).toLocaleString("vi-VN");
  }

  function renderStats() {
    setStat("totalProjects", state.stats.total_projects);
    setStat("totalUsers", state.stats.total_users);
    setStat("totalFeedbacks", state.stats.total_feedbacks);
    const feedbackTrend = document.querySelector(".feedback .trend");
    if (feedbackTrend) feedbackTrend.textContent = `${state.stats.pending_feedbacks || 0} mới`;
    const navCount = document.querySelector(".nav-item[data-section='feedbacks'] .nav-count");
    if (navCount) navCount.textContent = String(state.stats.pending_feedbacks || 0);
  }

  function renderAdminIdentity() {
    const chip = document.querySelector(".admin-chip");
    if (!chip) return;
    const name = state.currentAdmin.name || state.currentAdmin.email || "Admin";
    const avatar = chip.querySelector(".avatar");
    const strong = chip.querySelector("strong");
    const roleElement = chip.querySelector(".admin-copy span") || chip.querySelector("span");
    if (avatar) avatar.textContent = name.trim().charAt(0).toUpperCase() || "A";
    if (strong) strong.textContent = name;
    if (roleElement) roleElement.textContent = state.currentAdmin.role_name || "Admin";
  }

  function showToast(message, type = "error") {
    let toast = document.getElementById("adminToast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "adminToast";
      toast.className = "admin-toast";
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.dataset.type = type;
    toast.classList.add("show");
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => toast.classList.remove("show"), 3600);
  }

  function showTableMessage(id, message) {
    const tbody = document.getElementById(id);
    if (tbody) tbody.innerHTML = `<tr><td class="empty-row" colspan="8">${escapeHtml(message)}</td></tr>`;
  }

  function renderOverviewActivity(items = []) {
    const list = document.querySelector(".activity-list");
    if (!list) return;
    if (!items.length) {
      list.innerHTML = `<div class="activity-item"><span class="activity-icon cyan">•</span><div><strong>Chưa có hoạt động mới</strong><p>Dữ liệu hoạt động sẽ xuất hiện khi hệ thống phát sinh thay đổi.</p></div><time>—</time></div>`;
      return;
    }
    const iconByType = { project_created: ["purple", "✦"], user_created: ["green", "+"], feedback_created: ["amber", "!"] };
    list.innerHTML = items.map((item) => {
      const [tone, icon] = iconByType[item.type] || ["purple", "•"];
      return `<div class="activity-item"><span class="activity-icon ${tone}">${icon}</span><div><strong>${escapeHtml(item.title)}</strong><p>${escapeHtml(item.description)}</p></div><time>${escapeHtml(formatRelativeDate(item.created_at))}</time></div>`;
    }).join("");
  }

  function renderUsers() {
    const tbody = document.getElementById("userTableBody");
    if (!tbody) return;
    if (!state.users.length) {
      showTableMessage("userTableBody", "Không tìm thấy người dùng phù hợp.");
    } else {
      tbody.innerHTML = state.users.map((user) => `
        <tr>
          <td>#${user.id}</td>
          <td><div class="user-cell"><div class="mini-avatar">${escapeHtml(user.name.charAt(0).toUpperCase())}</div><strong>${escapeHtml(user.name)}</strong></div></td>
          <td>${escapeHtml(user.email)}</td>
          <td><span class="role-pill">${escapeHtml(user.role)}</span></td>
          <td>${escapeHtml(user.joinedAt)}</td>
          <td><span class="status-pill ${user.status === "suspended" ? "status-rejected" : ""}">${escapeHtml(userStatusLabels[user.status] || user.status)}</span></td>
          <td class="row-actions"><button type="button" data-action="edit" data-id="${user.id}">Sửa</button><button class="danger" type="button" data-action="delete" data-id="${user.id}">Xóa</button></td>
        </tr>`).join("");
    }
    const total = state.userPagination?.total ?? state.users.length;
    const current = state.userPagination?.page ?? state.userPage;
    const pages = state.userPagination?.total_pages ?? 1;
    document.getElementById("userResultCount").textContent = `${total} người dùng`;
    document.getElementById("userPageInfo").textContent = `Trang ${current}/${pages}`;
    document.getElementById("prevUserPage").disabled = !state.userPagination?.has_previous;
    document.getElementById("nextUserPage").disabled = !state.userPagination?.has_next;
  }

  function renderProjects() {
    const tbody = document.getElementById("projectTableBody");
    if (!tbody) return;
    if (!state.projects.length) {
      showTableMessage("projectTableBody", "Không tìm thấy dự án phù hợp.");
    } else {
      tbody.innerHTML = state.projects.map((project) => `
        <tr>
          <td>#${project.id}</td>
          <td><div class="project-cell"><strong>${escapeHtml(project.name)}</strong><span>${escapeHtml(project.description)}</span></div></td>
          <td>${escapeHtml(project.owner)}</td>
          <td>${project.members}</td>
          <td>${project.tasks}</td>
          <td><span class="status-pill">${escapeHtml(statusLabel(project.status))}</span></td>
          <td>${escapeHtml(project.createdAt)}</td>
          <td class="row-actions"><button type="button" data-action="view" data-id="${project.id}">Xem</button><button type="button" data-action="edit" data-id="${project.id}">Sửa</button><button class="danger" type="button" data-action="delete" data-id="${project.id}">Xóa</button></td>
        </tr>`).join("");
    }
    const total = state.projectPagination?.total ?? state.projects.length;
    const current = state.projectPagination?.page ?? state.projectPage;
    const pages = state.projectPagination?.total_pages ?? 1;
    document.getElementById("projectResultCount").textContent = `${total} dự án`;
    document.getElementById("projectPageInfo").textContent = `Trang ${current}/${pages}`;
    document.getElementById("prevProjectPage").disabled = !state.projectPagination?.has_previous;
    document.getElementById("nextProjectPage").disabled = !state.projectPagination?.has_next;
  }

  function renderFeedbacks() {
    const tbody = document.getElementById("feedbackTableBody");
    if (!tbody) return;
    if (!state.feedbacks.length) {
      showTableMessage("feedbackTableBody", "Không tìm thấy thư góp ý phù hợp.");
    } else {
      tbody.innerHTML = state.feedbacks.map((feedback) => `
        <tr>
          <td>#${feedback.id}</td>
          <td><div class="project-cell"><strong>${escapeHtml(feedback.title)}</strong><span>${escapeHtml(feedback.content)}</span></div></td>
          <td><div class="project-cell"><strong>${escapeHtml(feedback.sender)}</strong><span>${escapeHtml(feedback.email)}</span></div></td>
          <td>${feedback.attachment_count ?? feedback.attachments.length} file</td>
          <td><span class="status-pill status-${escapeHtml(feedback.status)}">${escapeHtml(feedbackStatusLabel(feedback.status))}</span></td>
          <td>${escapeHtml(feedback.createdAt)}</td>
          <td class="row-actions"><button type="button" data-action="view" data-id="${feedback.id}">Xem</button><button class="danger" type="button" data-action="delete" data-id="${feedback.id}">Xóa</button></td>
        </tr>`).join("");
    }
    const total = state.feedbackPagination?.total ?? state.feedbacks.length;
    const current = state.feedbackPagination?.page ?? state.feedbackPage;
    const pages = state.feedbackPagination?.total_pages ?? 1;
    document.getElementById("feedbackResultCount").textContent = `${total} góp ý`;
    document.getElementById("feedbackPageInfo").textContent = `Trang ${current}/${pages}`;
    document.getElementById("prevFeedbackPage").disabled = !state.feedbackPagination?.has_previous;
    document.getElementById("nextFeedbackPage").disabled = !state.feedbackPagination?.has_next;
  }

  async function loadOverview() {
    const response = await apiRequest(`/overview?activity_limit=5`);
    state.stats = response.data?.stats || state.stats;
    renderStats();
    renderOverviewActivity(response.data?.activity || []);
  }

  async function loadUsers() {
    const query = new URLSearchParams({ page: state.userPage, limit: state.usersPerPage });
    if (state.userSearch.trim()) query.set("q", state.userSearch.trim());
    const response = await apiRequest(`/users?${query}`);
    state.users = (response.data?.items || []).map(mapUser);
    state.userPagination = response.data?.pagination || null;
    renderUsers();
    if (state.activeSection === "overview") renderStats();
  }

  async function loadProjects() {
    const query = new URLSearchParams({ page: state.projectPage, limit: state.projectsPerPage });
    if (state.projectSearch.trim()) query.set("q", state.projectSearch.trim());
    const response = await apiRequest(`/projects?${query}`);
    state.projects = (response.data?.items || []).map(mapProject);
    state.projectPagination = response.data?.pagination || null;
    renderProjects();
  }

  async function loadFeedbacks() {
    const query = new URLSearchParams({ page: state.feedbackPage, limit: state.feedbacksPerPage });
    if (state.feedbackSearch.trim()) query.set("q", state.feedbackSearch.trim());
    if (state.feedbackStatusFilter !== "all") query.set("status", state.feedbackStatusFilter);
    const response = await apiRequest(`/feedbacks?${query}`);
    state.feedbacks = (response.data?.items || []).map(mapFeedback);
    state.feedbackPagination = response.data?.pagination || null;
    const counts = response.data?.status_counts || {};
    state.stats = {
      ...state.stats,
      pending_feedbacks: Number(counts.pending || 0),
      ...(state.feedbackStatusFilter === "all" && response.data?.pagination?.total !== undefined
        ? { total_feedbacks: response.data.pagination.total }
        : {}),
    };
    renderFeedbacks();
    renderStats();
  }

  async function loadSection(section) {
    state.isLoading = true;
    try {
      if (section === "overview") await loadOverview();
      if (section === "users") await loadUsers();
      if (section === "projects") await loadProjects();
      if (section === "feedbacks") await loadFeedbacks();
    } catch (error) {
      showToast(error.message || "Không thể tải dữ liệu.");
      if (section === "users") showTableMessage("userTableBody", error.message);
      if (section === "projects") showTableMessage("projectTableBody", error.message);
      if (section === "feedbacks") showTableMessage("feedbackTableBody", error.message);
    } finally {
      state.isLoading = false;
    }
  }

  async function loadCatalogs() {
    try {
      const response = await apiRequest("/catalogs");
      const roles = response?.data?.system_roles;
      if (Array.isArray(roles) && roles.length) {
        state.systemRoles = roles
          .map((role) => ({ id: Number(role.id), name: role.name || `Role ${role.id}` }))
          .filter((role) => Number.isInteger(role.id) && role.id > 0);
        renderUserRoleOptions();
      }
    } catch (error) {
      console.warn("Cannot load admin catalogs:", error);
    }
  }

  function closeMobileSidebar() {
    document.body.classList.remove("sidebar-open");
    document.getElementById("mobileMenuBtn")?.setAttribute("aria-expanded", "false");
  }

  function switchSection(section) {
    if (!pageTitles[section]) return;
    state.activeSection = section;
    document.querySelectorAll(".page-section").forEach((element) => element.classList.remove("active"));
    document.getElementById(`${section}Section`)?.classList.add("active");
    document.querySelectorAll(".nav-item").forEach((element) => element.classList.toggle("active", element.dataset.section === section));
    const title = document.getElementById("pageTitle");
    const breadcrumb = document.getElementById("breadcrumbCurrent");
    if (title) title.textContent = pageTitles[section];
    if (breadcrumb) breadcrumb.textContent = section === "overview" ? "Overview" : pageTitles[section].replace("Quản lý ", "");
    closeMobileSidebar();
    void loadSection(section);
  }

  function ensureUserPasswordField() {
    let input = document.getElementById("userPasswordInput");
    if (input) return input;
    const roleInput = document.getElementById("userRoleInput");
    if (!roleInput) return null;
    const label = document.createElement("label");
    label.id = "userPasswordField";
    label.innerHTML = "Mật khẩu <input id=\"userPasswordInput\" type=\"password\" minlength=\"6\" autocomplete=\"new-password\" placeholder=\"Tối thiểu 6 ký tự\" />";
    roleInput.closest("label")?.before(label);
    return document.getElementById("userPasswordInput");
  }

  function openUserModal(user = null) {
    const passwordInput = ensureUserPasswordField();
    document.getElementById("userModalTitle").textContent = user ? "Sửa người dùng" : "Thêm người dùng";
    document.getElementById("editingUserId").value = user?.id || "";
    document.getElementById("userNameInput").value = user?.name || "";
    document.getElementById("userEmailInput").value = user?.email || "";
    renderUserRoleOptions(user?.role_id || (user?.role === "Admin" ? 1 : 2));
    document.getElementById("userStatusInput").value = userStatusLabels[user?.status] || user?.status || "active";
    if (passwordInput) {
      passwordInput.value = "";
      passwordInput.required = !user;
      const passwordField = passwordInput.closest("label");
      if (passwordField) passwordField.style.display = user ? "none" : "grid";
    }
    document.getElementById("userModal").classList.add("open");
    document.getElementById("userModal").setAttribute("aria-hidden", "false");
    document.getElementById("userNameInput").focus();
  }

  function closeUserModal() {
    document.getElementById("userModal").classList.remove("open");
    document.getElementById("userModal").setAttribute("aria-hidden", "true");
    document.getElementById("userForm").reset();
  }

  function resolveOwnerId(value) {
    const text = String(value || "").trim();
    if (/^\d+$/.test(text)) return Number(text);
    const user = state.users.find((item) => item.name.toLowerCase() === text.toLowerCase() || item.email.toLowerCase() === text.toLowerCase());
    return user?.id || null;
  }

  function openProjectModal(project = null) {
    document.getElementById("projectModalTitle").textContent = project ? "Sửa dự án" : "Thêm dự án";
    document.getElementById("editingProjectId").value = project?.id || "";
    document.getElementById("projectNameInput").value = project?.name || "";
    document.getElementById("projectDescriptionInput").value = project?.description || "";
    document.getElementById("projectOwnerInput").value = project?.owner_id || project?.owner || "";
    document.getElementById("projectMembersInput").value = project?.members ?? 1;
    document.getElementById("projectTasksInput").value = project?.tasks ?? 0;
    const projectStatusInput = document.getElementById("projectStatusInput");
    projectStatusInput.value = projectStatusLabels[project?.status] ? project.status : normalizeProjectStatus(project?.status);
    document.getElementById("projectModal").classList.add("open");
    document.getElementById("projectModal").setAttribute("aria-hidden", "false");
    document.getElementById("projectNameInput").focus();
  }

  function closeProjectModal() {
    document.getElementById("projectModal").classList.remove("open");
    document.getElementById("projectModal").setAttribute("aria-hidden", "true");
    document.getElementById("projectForm").reset();
  }

  async function openFeedbackModal(feedback) {
    if (!feedback) return;
    state.selectedFeedbackId = feedback.id;
    document.getElementById("feedbackDetailTitle").textContent = feedback.title;
    document.getElementById("feedbackDetailSender").textContent = `${feedback.sender} - ${feedback.email}`;
    document.getElementById("feedbackDetailContent").textContent = feedback.content;
    document.getElementById("feedbackDetailStatus").value = feedback.status;
    renderAttachments(feedback.attachments);
    document.getElementById("feedbackModal").classList.add("open");
    document.getElementById("feedbackModal").setAttribute("aria-hidden", "false");
    try {
      const response = await apiRequest(`/feedbacks/${feedback.id}`);
      const detail = mapFeedback(response.data);
      document.getElementById("feedbackDetailTitle").textContent = detail.title;
      document.getElementById("feedbackDetailSender").textContent = `${detail.sender} - ${detail.email}`;
      document.getElementById("feedbackDetailContent").textContent = detail.content;
      document.getElementById("feedbackDetailStatus").value = detail.status;
      renderAttachments(detail.attachments);
    } catch (error) {
      showToast(error.message);
    }
  }

  function renderAttachments(attachments = []) {
    const list = document.getElementById("feedbackDetailAttachments");
    if (!list) return;
    list.innerHTML = attachments.length
      ? attachments.map((attachment) => `<a class="attachment-chip" href="${escapeHtml(attachment.url)}" target="_blank" rel="noopener"><span>${escapeHtml(attachmentLabel(attachment.type))}</span>${escapeHtml(attachment.name)}</a>`).join("")
      : `<span class="muted-text">Không có file đính kèm</span>`;
  }

  function closeFeedbackModal() {
    state.selectedFeedbackId = null;
    document.getElementById("feedbackModal").classList.remove("open");
    document.getElementById("feedbackModal").setAttribute("aria-hidden", "true");
  }

  async function saveUser(event) {
    event.preventDefault();
    const editingId = Number(document.getElementById("editingUserId").value);
    const password = document.getElementById("userPasswordInput")?.value || "";
    const payload = {
      name: document.getElementById("userNameInput").value.trim(),
      email: document.getElementById("userEmailInput").value.trim(),
      system_role_id: Number.parseInt(document.getElementById("userRoleInput").value, 10),
      status: normalizeUserStatus(document.getElementById("userStatusInput").value),
    };
    if (!editingId) payload.password = password;
    if (!payload.name || !payload.email || !Number.isInteger(payload.system_role_id) || payload.system_role_id < 1 || (!editingId && password.length < 6)) {
      showToast("Vui lòng nhập đủ thông tin và mật khẩu tối thiểu 6 ký tự.");
      return;
    }
    try {
      if (editingId) {
        await apiRequest(`/users/${editingId}`, { method: "PATCH", body: JSON.stringify(payload) });
      } else {
        await apiRequest("/users", { method: "POST", body: JSON.stringify(payload) });
      }
      closeUserModal();
      showToast(editingId ? "Đã cập nhật người dùng." : "Đã tạo người dùng.", "success");
      await Promise.all([loadUsers(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  async function saveProject(event) {
    event.preventDefault();
    const editingId = Number(document.getElementById("editingProjectId").value);
    const ownerId = resolveOwnerId(document.getElementById("projectOwnerInput").value);
    const payload = {
      name: document.getElementById("projectNameInput").value.trim(),
      description: document.getElementById("projectDescriptionInput").value.trim(),
      owner_id: ownerId,
      status: normalizeProjectStatus(document.getElementById("projectStatusInput").value),
    };
    if (!payload.name || !payload.owner_id) {
      showToast("Tên dự án hợp lệ và owner_id là bắt buộc. Có thể nhập ID hoặc tên/email người dùng.");
      return;
    }
    try {
      if (editingId) {
        await apiRequest(`/projects/${editingId}`, { method: "PATCH", body: JSON.stringify(payload) });
      } else {
        await apiRequest("/projects", { method: "POST", body: JSON.stringify(payload) });
      }
      closeProjectModal();
      showToast(editingId ? "Đã cập nhật dự án." : "Đã tạo dự án.", "success");
      await Promise.all([loadProjects(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  async function deleteUser(id) {
    const user = state.users.find((item) => item.id === id);
    if (!user || !window.confirm(`Xóa người dùng "${user.name}"?`)) return;
    try {
      await apiRequest(`/users/${id}?confirm=${id}`, { method: "DELETE" });
      showToast("Đã xóa người dùng.", "success");
      await Promise.all([loadUsers(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  async function deleteProject(id) {
    const project = state.projects.find((item) => item.id === id);
    if (!project || !window.confirm(`Xóa dự án "${project.name}"? Dữ liệu liên quan có thể bị xóa theo.`)) return;
    try {
      await apiRequest(`/projects/${id}?confirm=${id}`, { method: "DELETE" });
      showToast("Đã xóa dự án.", "success");
      await Promise.all([loadProjects(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  async function saveFeedbackStatus() {
    if (!state.selectedFeedbackId) return;
    const status = document.getElementById("feedbackDetailStatus").value;
    try {
      await apiRequest(`/feedbacks/${state.selectedFeedbackId}/status`, { method: "PATCH", body: JSON.stringify({ status }) });
      closeFeedbackModal();
      showToast("Đã cập nhật trạng thái góp ý.", "success");
      await Promise.all([loadFeedbacks(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  async function deleteFeedback(id) {
    const feedback = state.feedbacks.find((item) => item.id === id);
    if (!feedback || !window.confirm(`Xóa thư góp ý "${feedback.title}"?`)) return;
    try {
      await apiRequest(`/feedbacks/${id}`, { method: "DELETE" });
      showToast("Đã xóa thư góp ý.", "success");
      await Promise.all([loadFeedbacks(), loadOverview()]);
    } catch (error) {
      showToast(error.message);
    }
  }

  function bindEvents() {
    document.querySelectorAll("[data-section]").forEach((element) => {
      element.addEventListener("click", (event) => {
        event.preventDefault();
        switchSection(element.dataset.section);
      });
    });

    document.getElementById("userSearch")?.addEventListener("input", (event) => {
      state.userSearch = event.target.value;
      state.userPage = 1;
      void loadUsers();
    });
    document.getElementById("projectSearch")?.addEventListener("input", (event) => {
      state.projectSearch = event.target.value;
      state.projectPage = 1;
      void loadProjects();
    });
    document.getElementById("feedbackSearch")?.addEventListener("input", (event) => {
      state.feedbackSearch = event.target.value;
      state.feedbackPage = 1;
      void loadFeedbacks();
    });
    document.getElementById("feedbackStatusFilter")?.addEventListener("change", (event) => {
      state.feedbackStatusFilter = event.target.value;
      state.feedbackPage = 1;
      void loadFeedbacks();
    });

    document.getElementById("prevUserPage")?.addEventListener("click", () => { state.userPage = Math.max(1, state.userPage - 1); void loadUsers(); });
    document.getElementById("nextUserPage")?.addEventListener("click", () => { state.userPage += 1; void loadUsers(); });
    document.getElementById("prevProjectPage")?.addEventListener("click", () => { state.projectPage = Math.max(1, state.projectPage - 1); void loadProjects(); });
    document.getElementById("nextProjectPage")?.addEventListener("click", () => { state.projectPage += 1; void loadProjects(); });
    document.getElementById("prevFeedbackPage")?.addEventListener("click", () => { state.feedbackPage = Math.max(1, state.feedbackPage - 1); void loadFeedbacks(); });
    document.getElementById("nextFeedbackPage")?.addEventListener("click", () => { state.feedbackPage += 1; void loadFeedbacks(); });

    document.getElementById("addUserBtn")?.addEventListener("click", () => openUserModal());
    document.getElementById("addProjectBtn")?.addEventListener("click", () => openProjectModal());
    document.getElementById("closeUserModal")?.addEventListener("click", closeUserModal);
    document.getElementById("cancelUserForm")?.addEventListener("click", closeUserModal);
    document.getElementById("userForm")?.addEventListener("submit", saveUser);
    document.getElementById("closeProjectModal")?.addEventListener("click", closeProjectModal);
    document.getElementById("cancelProjectForm")?.addEventListener("click", closeProjectModal);
    document.getElementById("projectForm")?.addEventListener("submit", saveProject);
    document.getElementById("closeFeedbackModal")?.addEventListener("click", closeFeedbackModal);
    document.getElementById("cancelFeedbackModal")?.addEventListener("click", closeFeedbackModal);
    document.getElementById("saveFeedbackStatusBtn")?.addEventListener("click", saveFeedbackStatus);

    ["userModal", "projectModal", "feedbackModal"].forEach((id) => {
      document.getElementById(id)?.addEventListener("click", (event) => {
        if (event.target.id === id) ({ userModal: closeUserModal, projectModal: closeProjectModal, feedbackModal: closeFeedbackModal }[id])();
      });
    });

    document.getElementById("userTableBody")?.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-action]");
      if (!button) return;
      const id = Number(button.dataset.id);
      if (button.dataset.action === "edit") openUserModal(state.users.find((item) => item.id === id));
      if (button.dataset.action === "delete") void deleteUser(id);
    });
    document.getElementById("projectTableBody")?.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-action]");
      if (!button) return;
      const id = Number(button.dataset.id);
      if (button.dataset.action === "view") window.location.href = `./project-detail.html?id=${id}`;
      if (button.dataset.action === "edit") openProjectModal(state.projects.find((item) => item.id === id));
      if (button.dataset.action === "delete") void deleteProject(id);
    });
    document.getElementById("feedbackTableBody")?.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-action]");
      if (!button) return;
      const id = Number(button.dataset.id);
      if (button.dataset.action === "view") void openFeedbackModal(state.feedbacks.find((item) => item.id === id));
      if (button.dataset.action === "delete") void deleteFeedback(id);
    });

    document.querySelector(".logout-btn")?.addEventListener("click", () => {
      clearSession();
      window.location.replace("./login.html");
    });
    document.getElementById("mobileMenuBtn")?.addEventListener("click", () => {
      const isOpen = document.body.classList.toggle("sidebar-open");
      document.getElementById("mobileMenuBtn")?.setAttribute("aria-expanded", String(isOpen));
    });
    document.getElementById("sidebarOverlay")?.addEventListener("click", closeMobileSidebar);
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        closeMobileSidebar();
        closeUserModal();
        closeProjectModal();
        closeFeedbackModal();
      }
    });
  }

  function injectApiToastStyles() {
    const style = document.createElement("style");
    style.textContent = `.admin-toast{position:fixed;right:24px;bottom:24px;z-index:10000;max-width:min(380px,calc(100vw - 48px));padding:13px 16px;color:#dffaff;border:1px solid rgba(101,220,255,.28);border-radius:11px;background:rgba(14,27,46,.96);box-shadow:0 16px 38px rgba(0,0,0,.35);font:600 12px/1.45 \"DM Sans\",sans-serif;opacity:0;pointer-events:none;transform:translateY(10px);transition:opacity .2s ease,transform .2s ease}.admin-toast.show{opacity:1;transform:translateY(0)}.admin-toast[data-type=success]{border-color:rgba(102,225,173,.32);color:#c9ffe8}.admin-toast[data-type=error]{border-color:rgba(255,129,153,.32);color:#ffd5de}`;
    document.head.appendChild(style);
  }

  injectApiToastStyles();
  renderAdminIdentity();
  renderStats();
  bindEvents();
  renderUserRoleOptions();
  void loadCatalogs();
  switchSection(window.location.hash.replace("#", "") || "overview");
})();

