const API_BASE_URL = window.location.protocol === "file:"
  ? "http://localhost:3000/api"
  : `${window.location.origin}/api`;
const TOKEN_KEY = "quanlyduan_admin_token";
const USER_KEY = "quanlyduan_admin_user";

const form = document.getElementById("adminLoginForm");
const emailInput = document.getElementById("adminEmail");
const passwordInput = document.getElementById("adminPassword");
const errorText = document.getElementById("loginError");
const submitBtn = document.getElementById("loginSubmitBtn");
const togglePasswordBtn = document.getElementById("togglePasswordBtn");

function setError(message) {
  errorText.textContent = message || "";
}

function setLoading(isLoading) {
  submitBtn.disabled = isLoading;
  submitBtn.textContent = isLoading ? "Đang đăng nhập..." : "Đăng nhập";
}

function isAdminUser(user) {
  const roleName = String(user?.role_name || "").trim().toLowerCase();
  return Number(user?.system_role_id) === 1 ||
    ["admin", "administrator", "quan tri vien", "quản trị viên"].includes(roleName);
}

function redirectIfLoggedIn() {
  const token = localStorage.getItem(TOKEN_KEY);
  const rawUser = localStorage.getItem(USER_KEY);
  if (!token || !rawUser) return;

  try {
    const user = JSON.parse(rawUser);
    if (isAdminUser(user)) {
      window.location.replace("./index.html");
    }
  } catch (_) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }
}

togglePasswordBtn.addEventListener("click", () => {
  const shouldShow = passwordInput.type === "password";
  passwordInput.type = shouldShow ? "text" : "password";
  togglePasswordBtn.textContent = shouldShow ? "Ẩn" : "Hiện";
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  setError("");
  setLoading(true);

  try {
    const response = await fetch(`${API_BASE_URL}/auth/admin-login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: emailInput.value.trim(),
        password: passwordInput.value,
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok || !data.success) {
      throw new Error(data.message || "Đăng nhập thất bại.");
    }

    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(USER_KEY, JSON.stringify(data.user));
    window.location.replace("./index.html");
  } catch (error) {
    setError(error.message || "Không thể kết nối API.");
  } finally {
    setLoading(false);
  }
});

redirectIfLoggedIn();
