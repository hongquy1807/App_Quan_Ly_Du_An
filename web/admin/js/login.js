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
const submitLabel = submitBtn?.querySelector(".button-label");
const togglePasswordBtn = document.getElementById("togglePasswordBtn");

function setError(message) {
  errorText.textContent = message || "";
  errorText.hidden = !message;
  if (message) {
    form.classList.add("has-error");
  } else {
    form.classList.remove("has-error");
  }
}

function setLoading(isLoading) {
  submitBtn.disabled = isLoading;
  submitBtn.classList.toggle("is-loading", isLoading);
  submitBtn.setAttribute("aria-busy", String(isLoading));
  if (submitLabel) {
    submitLabel.textContent = isLoading ? "Đang xác thực..." : "Truy cập hệ thống";
  }
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

function validateForm() {
  if (!emailInput.value.trim()) {
    setError("Vui lòng nhập địa chỉ email.");
    emailInput.focus();
    return false;
  }

  if (!emailInput.validity.valid) {
    setError("Vui lòng kiểm tra lại định dạng email.");
    emailInput.focus();
    return false;
  }

  if (!passwordInput.value) {
    setError("Vui lòng nhập mật khẩu.");
    passwordInput.focus();
    return false;
  }

  return true;
}

togglePasswordBtn.addEventListener("click", () => {
  const shouldShow = passwordInput.type === "password";
  passwordInput.type = shouldShow ? "text" : "password";
  togglePasswordBtn.textContent = shouldShow ? "Ẩn" : "Hiện";
  togglePasswordBtn.setAttribute("aria-label", shouldShow ? "Ẩn mật khẩu" : "Hiện mật khẩu");
  togglePasswordBtn.setAttribute("aria-pressed", String(shouldShow));
  passwordInput.focus();
});

[emailInput, passwordInput].forEach((input) => {
  input.addEventListener("input", () => {
    if (errorText.textContent) setError("");
  });
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  setError("");

  if (!validateForm()) return;

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
      throw new Error(data.message || "Email hoặc mật khẩu chưa chính xác.");
    }

    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(USER_KEY, JSON.stringify(data.user));
    window.location.replace("./index.html");
  } catch (error) {
    const isNetworkError = error instanceof TypeError;
    setError(isNetworkError ? "Không thể kết nối máy chủ. Vui lòng thử lại sau." : (error.message || "Đăng nhập thất bại."));
  } finally {
    setLoading(false);
  }
});

redirectIfLoggedIn();
