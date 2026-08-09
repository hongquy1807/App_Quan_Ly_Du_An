const pageTitles = {
  overview: "Tổng quan hệ thống",
  users: "Quản lý người dùng",
  projects: "Quản lý dự án",
  feedbacks: "Quản lý thư góp ý",
};

const state = {
  activeSection: "overview",
  userPage: 1,
  usersPerPage: 20,
  userSearch: "",
  projectPage: 1,
  projectsPerPage: 20,
  projectSearch: "",
  feedbackPage: 1,
  feedbacksPerPage: 20,
  feedbackSearch: "",
  feedbackStatusFilter: "all",
  selectedFeedbackId: null,
  users: [
    { id: 1, name: "Quản trị viên", email: "admin@company.com", role: "Admin", joinedAt: "08/07/2026", status: "Hoạt động" },
    { id: 2, name: "Nguyễn Văn An", email: "manager@company.com", role: "Member", joinedAt: "08/07/2026", status: "Hoạt động" },
    { id: 6, name: "Phạm Hồng Quý", email: "hongquy@gmail.com", role: "Member", joinedAt: "08/07/2026", status: "Hoạt động" },
    { id: 7, name: "Nguyễn Văn Kha", email: "kha2000@gmail.com", role: "Member", joinedAt: "17/07/2026", status: "Hoạt động" },
    { id: 8, name: "Trần Thị B", email: "test@gmail.com", role: "Member", joinedAt: "27/07/2026", status: "Hoạt động" },
    { id: 9, name: "Lê Văn C", email: "testq@gmail.com", role: "Member", joinedAt: "29/07/2026", status: "Hoạt động" },
    { id: 10, name: "Phạm Thị D", email: "q@gmail.com", role: "Member", joinedAt: "29/07/2026", status: "Hoạt động" },
  ],
  projects: [
    { id: 8, name: "Ứng dụng quản lý kho", description: "Quản lý nhập xuất tồn kho", owner: "Trần Thị B", members: 4, tasks: 12, status: "Đang thực hiện", createdAt: "29/07/2026" },
    { id: 12, name: "Website bán hàng", description: "Website quản lý bán hàng", owner: "Phạm Thị D", members: 3, tasks: 8, status: "Lên kế hoạch", createdAt: "29/07/2026" },
    { id: 16, name: "Lập trình di động", description: "Ứng dụng quản lý dự án mobile", owner: "Phạm Hồng Quý", members: 3, tasks: 5, status: "Đang thực hiện", createdAt: "31/07/2026" },
    { id: 17, name: "Sinh nhật Thu", description: "Chuẩn bị sinh nhật", owner: "Phạm Hồng Quý", members: 1, tasks: 3, status: "Đang thực hiện", createdAt: "03/08/2026" },
  ],
  feedbacks: [
    {
      id: 1,
      title: "Lỗi theme tối trang lịch",
      content: "Khi chuyển sang chế độ tối, một vài khung trong trang lịch vẫn còn nền sáng.",
      sender: "Phạm Hồng Quý",
      email: "hongquy@gmail.com",
      status: "pending",
      createdAt: "06/08/2026",
      attachments: [
        { name: "timeline_dark.png", type: "image", url: "#" },
      ],
    },
    {
      id: 2,
      title: "Góp ý trang tạo nhiệm vụ",
      content: "Nên cho phép chọn nhiều thành viên nhanh hơn và hiển thị rõ người nhận task.",
      sender: "Trần Thị B",
      email: "test@gmail.com",
      status: "reviewing",
      createdAt: "05/08/2026",
      attachments: [
        { name: "demo.mp4", type: "video", url: "#" },
        { name: "note.pdf", type: "document", url: "#" },
      ],
    },
    {
      id: 3,
      title: "Cải thiện thông báo",
      content: "Thông báo nên tự đánh dấu đã đọc khi người dùng nhấn vào.",
      sender: "Lê Văn C",
      email: "testq@gmail.com",
      status: "resolved",
      createdAt: "04/08/2026",
      attachments: [],
    },
  ],
};

const fallbackStats = {
  totalProjects: state.projects.length,
  totalUsers: state.users.length,
  totalFeedbacks: state.feedbacks.length,
};

function setStat(id, value) {
  const element = document.getElementById(id);
  if (!element) return;
  element.textContent = Number(value || 0).toLocaleString("vi-VN");
}

function renderStats(stats = fallbackStats) {
  setStat("totalProjects", state.projects.length || stats.totalProjects);
  setStat("totalUsers", state.users.length || stats.totalUsers);
  setStat("totalFeedbacks", state.feedbacks.length || stats.totalFeedbacks);
}

function switchSection(section) {
  state.activeSection = section;
  document.querySelectorAll(".page-section").forEach((element) => {
    element.classList.remove("active");
  });
  document.getElementById(`${section}Section`)?.classList.add("active");

  document.querySelectorAll(".nav-item").forEach((element) => {
    element.classList.toggle("active", element.dataset.section === section);
  });

  document.getElementById("pageTitle").textContent = pageTitles[section];
}

function filteredUsers() {
  const query = state.userSearch.trim().toLowerCase();
  if (!query) return [...state.users];
  return state.users.filter((user) =>
    user.name.toLowerCase().includes(query) ||
    user.email.toLowerCase().includes(query)
  );
}

function filteredProjects() {
  const query = state.projectSearch.trim().toLowerCase();
  if (!query) return [...state.projects];
  return state.projects.filter((project) =>
    project.name.toLowerCase().includes(query) ||
    project.owner.toLowerCase().includes(query) ||
    project.description.toLowerCase().includes(query)
  );
}

function statusLabel(status) {
  switch (status) {
    case "pending":
      return "Chờ xử lý";
    case "reviewing":
      return "Đang xem xét";
    case "resolved":
      return "Đã xử lý";
    case "rejected":
      return "Từ chối";
    default:
      return status;
  }
}

function attachmentLabel(type) {
  switch (type) {
    case "image":
      return "Ảnh";
    case "video":
      return "Video";
    case "document":
      return "Tài liệu";
    default:
      return "File";
  }
}

function filteredFeedbacks() {
  const query = state.feedbackSearch.trim().toLowerCase();
  return state.feedbacks.filter((feedback) => {
    const matchesSearch = !query ||
      feedback.title.toLowerCase().includes(query) ||
      feedback.content.toLowerCase().includes(query) ||
      feedback.sender.toLowerCase().includes(query) ||
      feedback.email.toLowerCase().includes(query);
    const matchesStatus =
      state.feedbackStatusFilter === "all" ||
      feedback.status === state.feedbackStatusFilter;
    return matchesSearch && matchesStatus;
  });
}

function renderUsers() {
  const users = filteredUsers();
  const totalPages = Math.max(1, Math.ceil(users.length / state.usersPerPage));
  state.userPage = Math.min(state.userPage, totalPages);

  const start = (state.userPage - 1) * state.usersPerPage;
  const pageUsers = users.slice(start, start + state.usersPerPage);
  const tableBody = document.getElementById("userTableBody");

  tableBody.innerHTML = pageUsers.map((user) => `
    <tr>
      <td>#${user.id}</td>
      <td>
        <div class="user-cell">
          <div class="mini-avatar">${user.name.charAt(0).toUpperCase()}</div>
          <strong>${user.name}</strong>
        </div>
      </td>
      <td>${user.email}</td>
      <td><span class="role-pill">${user.role}</span></td>
      <td>${user.joinedAt}</td>
      <td><span class="status-pill">${user.status}</span></td>
      <td class="row-actions">
        <button type="button" data-action="edit" data-id="${user.id}">Sửa</button>
        <button class="danger" type="button" data-action="delete" data-id="${user.id}">Xóa</button>
      </td>
    </tr>
  `).join("");

  if (pageUsers.length === 0) {
    tableBody.innerHTML = `<tr><td class="empty-row" colspan="7">Không tìm thấy người dùng phù hợp.</td></tr>`;
  }

  document.getElementById("userResultCount").textContent = `${users.length} người dùng`;
  document.getElementById("userPageInfo").textContent = `Trang ${state.userPage}/${totalPages}`;
  document.getElementById("prevUserPage").disabled = state.userPage <= 1;
  document.getElementById("nextUserPage").disabled = state.userPage >= totalPages;
  renderStats();
}

function renderProjects() {
  const projects = filteredProjects();
  const totalPages = Math.max(1, Math.ceil(projects.length / state.projectsPerPage));
  state.projectPage = Math.min(state.projectPage, totalPages);

  const start = (state.projectPage - 1) * state.projectsPerPage;
  const pageProjects = projects.slice(start, start + state.projectsPerPage);
  const tableBody = document.getElementById("projectTableBody");

  tableBody.innerHTML = pageProjects.map((project) => `
    <tr>
      <td>#${project.id}</td>
      <td>
        <div class="project-cell">
          <strong>${project.name}</strong>
          <span>${project.description}</span>
        </div>
      </td>
      <td>${project.owner}</td>
      <td>${project.members}</td>
      <td>${project.tasks}</td>
      <td><span class="status-pill">${project.status}</span></td>
      <td>${project.createdAt}</td>
      <td class="row-actions">
        <button type="button" data-action="edit" data-id="${project.id}">Sửa</button>
        <button class="danger" type="button" data-action="delete" data-id="${project.id}">Xóa</button>
      </td>
    </tr>
  `).join("");

  if (pageProjects.length === 0) {
    tableBody.innerHTML = `<tr><td class="empty-row" colspan="8">Không tìm thấy dự án phù hợp.</td></tr>`;
  }

  document.getElementById("projectResultCount").textContent = `${projects.length} dự án`;
  document.getElementById("projectPageInfo").textContent = `Trang ${state.projectPage}/${totalPages}`;
  document.getElementById("prevProjectPage").disabled = state.projectPage <= 1;
  document.getElementById("nextProjectPage").disabled = state.projectPage >= totalPages;
  renderStats();
}

function renderFeedbacks() {
  const feedbacks = filteredFeedbacks();
  const totalPages = Math.max(1, Math.ceil(feedbacks.length / state.feedbacksPerPage));
  state.feedbackPage = Math.min(state.feedbackPage, totalPages);

  const start = (state.feedbackPage - 1) * state.feedbacksPerPage;
  const pageFeedbacks = feedbacks.slice(start, start + state.feedbacksPerPage);
  const tableBody = document.getElementById("feedbackTableBody");

  tableBody.innerHTML = pageFeedbacks.map((feedback) => `
    <tr>
      <td>#${feedback.id}</td>
      <td>
        <div class="project-cell">
          <strong>${feedback.title}</strong>
          <span>${feedback.content}</span>
        </div>
      </td>
      <td>
        <div class="project-cell">
          <strong>${feedback.sender}</strong>
          <span>${feedback.email}</span>
        </div>
      </td>
      <td>${feedback.attachments.length} file</td>
      <td><span class="status-pill status-${feedback.status}">${statusLabel(feedback.status)}</span></td>
      <td>${feedback.createdAt}</td>
      <td class="row-actions">
        <button type="button" data-action="view" data-id="${feedback.id}">Xem</button>
        <button class="danger" type="button" data-action="delete" data-id="${feedback.id}">Xóa</button>
      </td>
    </tr>
  `).join("");

  if (pageFeedbacks.length === 0) {
    tableBody.innerHTML = `<tr><td class="empty-row" colspan="7">Không tìm thấy thư góp ý phù hợp.</td></tr>`;
  }

  document.getElementById("feedbackResultCount").textContent = `${feedbacks.length} góp ý`;
  document.getElementById("feedbackPageInfo").textContent = `Trang ${state.feedbackPage}/${totalPages}`;
  document.getElementById("prevFeedbackPage").disabled = state.feedbackPage <= 1;
  document.getElementById("nextFeedbackPage").disabled = state.feedbackPage >= totalPages;
  renderStats();
}

function openUserModal(user = null) {
  document.getElementById("userModalTitle").textContent = user ? "Sửa người dùng" : "Thêm người dùng";
  document.getElementById("editingUserId").value = user?.id || "";
  document.getElementById("userNameInput").value = user?.name || "";
  document.getElementById("userEmailInput").value = user?.email || "";
  document.getElementById("userRoleInput").value = user?.role || "Member";
  document.getElementById("userStatusInput").value = user?.status || "Hoạt động";
  document.getElementById("userModal").classList.add("open");
  document.getElementById("userModal").setAttribute("aria-hidden", "false");
}

function closeUserModal() {
  document.getElementById("userModal").classList.remove("open");
  document.getElementById("userModal").setAttribute("aria-hidden", "true");
  document.getElementById("userForm").reset();
}

function openProjectModal(project = null) {
  document.getElementById("projectModalTitle").textContent = project ? "Sửa dự án" : "Thêm dự án";
  document.getElementById("editingProjectId").value = project?.id || "";
  document.getElementById("projectNameInput").value = project?.name || "";
  document.getElementById("projectDescriptionInput").value = project?.description || "";
  document.getElementById("projectOwnerInput").value = project?.owner || "";
  document.getElementById("projectMembersInput").value = project?.members ?? 1;
  document.getElementById("projectTasksInput").value = project?.tasks ?? 0;
  document.getElementById("projectStatusInput").value = project?.status || "Đang thực hiện";
  document.getElementById("projectModal").classList.add("open");
  document.getElementById("projectModal").setAttribute("aria-hidden", "false");
}

function closeProjectModal() {
  document.getElementById("projectModal").classList.remove("open");
  document.getElementById("projectModal").setAttribute("aria-hidden", "true");
  document.getElementById("projectForm").reset();
}

function openFeedbackModal(feedback) {
  if (!feedback) return;
  state.selectedFeedbackId = feedback.id;
  document.getElementById("feedbackDetailTitle").textContent = feedback.title;
  document.getElementById("feedbackDetailSender").textContent =
    `${feedback.sender} - ${feedback.email}`;
  document.getElementById("feedbackDetailContent").textContent = feedback.content;
  document.getElementById("feedbackDetailStatus").value = feedback.status;

  const attachmentList = document.getElementById("feedbackDetailAttachments");
  attachmentList.innerHTML = feedback.attachments.length
    ? feedback.attachments.map((attachment) => `
        <a class="attachment-chip" href="${attachment.url}">
          <span>${attachmentLabel(attachment.type)}</span>
          ${attachment.name}
        </a>
      `).join("")
    : `<span class="muted-text">Không có file đính kèm</span>`;

  document.getElementById("feedbackModal").classList.add("open");
  document.getElementById("feedbackModal").setAttribute("aria-hidden", "false");
}

function closeFeedbackModal() {
  state.selectedFeedbackId = null;
  document.getElementById("feedbackModal").classList.remove("open");
  document.getElementById("feedbackModal").setAttribute("aria-hidden", "true");
}

function saveUser(event) {
  event.preventDefault();
  const editingId = Number(document.getElementById("editingUserId").value);
  const payload = {
    name: document.getElementById("userNameInput").value.trim(),
    email: document.getElementById("userEmailInput").value.trim(),
    role: document.getElementById("userRoleInput").value,
    status: document.getElementById("userStatusInput").value,
  };

  if (editingId) {
    state.users = state.users.map((user) => user.id === editingId ? { ...user, ...payload } : user);
  } else {
    const nextId = Math.max(0, ...state.users.map((user) => user.id)) + 1;
    state.users.unshift({ id: nextId, ...payload, joinedAt: new Date().toLocaleDateString("vi-VN") });
    state.userPage = 1;
  }

  closeUserModal();
  renderUsers();
}

function saveProject(event) {
  event.preventDefault();
  const editingId = Number(document.getElementById("editingProjectId").value);
  const payload = {
    name: document.getElementById("projectNameInput").value.trim(),
    description: document.getElementById("projectDescriptionInput").value.trim(),
    owner: document.getElementById("projectOwnerInput").value.trim(),
    members: Number(document.getElementById("projectMembersInput").value || 0),
    tasks: Number(document.getElementById("projectTasksInput").value || 0),
    status: document.getElementById("projectStatusInput").value,
  };

  if (editingId) {
    state.projects = state.projects.map((project) =>
      project.id === editingId ? { ...project, ...payload } : project
    );
  } else {
    const nextId = Math.max(0, ...state.projects.map((project) => project.id)) + 1;
    state.projects.unshift({ id: nextId, ...payload, createdAt: new Date().toLocaleDateString("vi-VN") });
    state.projectPage = 1;
  }

  closeProjectModal();
  renderProjects();
}

function deleteUser(id) {
  const user = state.users.find((item) => item.id === id);
  if (!user || !window.confirm(`Xóa người dùng "${user.name}"?`)) return;
  state.users = state.users.filter((item) => item.id !== id);
  renderUsers();
}

function deleteProject(id) {
  const project = state.projects.find((item) => item.id === id);
  if (!project || !window.confirm(`Xóa dự án "${project.name}"?`)) return;
  state.projects = state.projects.filter((item) => item.id !== id);
  renderProjects();
}

function saveFeedbackStatus() {
  const status = document.getElementById("feedbackDetailStatus").value;
  state.feedbacks = state.feedbacks.map((feedback) =>
    feedback.id === state.selectedFeedbackId ? { ...feedback, status } : feedback
  );
  closeFeedbackModal();
  renderFeedbacks();
}

function deleteFeedback(id) {
  const feedback = state.feedbacks.find((item) => item.id === id);
  if (!feedback || !window.confirm(`Xóa thư góp ý "${feedback.title}"?`)) return;
  state.feedbacks = state.feedbacks.filter((item) => item.id !== id);
  renderFeedbacks();
}

document.querySelectorAll("[data-section]").forEach((element) => {
  element.addEventListener("click", (event) => {
    event.preventDefault();
    switchSection(element.dataset.section);
  });
});

document.getElementById("userSearch").addEventListener("input", (event) => {
  state.userSearch = event.target.value;
  state.userPage = 1;
  renderUsers();
});

document.getElementById("projectSearch").addEventListener("input", (event) => {
  state.projectSearch = event.target.value;
  state.projectPage = 1;
  renderProjects();
});

document.getElementById("feedbackSearch").addEventListener("input", (event) => {
  state.feedbackSearch = event.target.value;
  state.feedbackPage = 1;
  renderFeedbacks();
});

document.getElementById("feedbackStatusFilter").addEventListener("change", (event) => {
  state.feedbackStatusFilter = event.target.value;
  state.feedbackPage = 1;
  renderFeedbacks();
});

document.getElementById("prevUserPage").addEventListener("click", () => {
  state.userPage -= 1;
  renderUsers();
});

document.getElementById("nextUserPage").addEventListener("click", () => {
  state.userPage += 1;
  renderUsers();
});

document.getElementById("prevProjectPage").addEventListener("click", () => {
  state.projectPage -= 1;
  renderProjects();
});

document.getElementById("nextProjectPage").addEventListener("click", () => {
  state.projectPage += 1;
  renderProjects();
});

document.getElementById("prevFeedbackPage").addEventListener("click", () => {
  state.feedbackPage -= 1;
  renderFeedbacks();
});

document.getElementById("nextFeedbackPage").addEventListener("click", () => {
  state.feedbackPage += 1;
  renderFeedbacks();
});

document.getElementById("addUserBtn").addEventListener("click", () => openUserModal());
document.getElementById("addProjectBtn").addEventListener("click", () => openProjectModal());

document.getElementById("closeUserModal").addEventListener("click", closeUserModal);
document.getElementById("cancelUserForm").addEventListener("click", closeUserModal);
document.getElementById("userForm").addEventListener("submit", saveUser);

document.getElementById("closeProjectModal").addEventListener("click", closeProjectModal);
document.getElementById("cancelProjectForm").addEventListener("click", closeProjectModal);
document.getElementById("projectForm").addEventListener("submit", saveProject);
document.getElementById("closeFeedbackModal").addEventListener("click", closeFeedbackModal);
document.getElementById("cancelFeedbackModal").addEventListener("click", closeFeedbackModal);
document.getElementById("saveFeedbackStatusBtn").addEventListener("click", saveFeedbackStatus);

document.getElementById("userModal").addEventListener("click", (event) => {
  if (event.target.id === "userModal") closeUserModal();
});

document.getElementById("projectModal").addEventListener("click", (event) => {
  if (event.target.id === "projectModal") closeProjectModal();
});

document.getElementById("feedbackModal").addEventListener("click", (event) => {
  if (event.target.id === "feedbackModal") closeFeedbackModal();
});

document.getElementById("userTableBody").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const id = Number(button.dataset.id);
  if (button.dataset.action === "edit") openUserModal(state.users.find((user) => user.id === id));
  if (button.dataset.action === "delete") deleteUser(id);
});

document.getElementById("projectTableBody").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const id = Number(button.dataset.id);
  if (button.dataset.action === "edit") openProjectModal(state.projects.find((project) => project.id === id));
  if (button.dataset.action === "delete") deleteProject(id);
});

document.getElementById("feedbackTableBody").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const id = Number(button.dataset.id);
  if (button.dataset.action === "view") {
    openFeedbackModal(state.feedbacks.find((feedback) => feedback.id === id));
  }
  if (button.dataset.action === "delete") deleteFeedback(id);
});

renderStats();
renderUsers();
renderProjects();
renderFeedbacks();
