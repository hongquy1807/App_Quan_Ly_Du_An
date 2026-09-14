# Quản lý dự án

Ứng dụng Flutter sử dụng backend Node.js/Express và cơ sở dữ liệu MySQL.

## 1. Chuẩn bị

Máy cần có Flutter (Dart tương thích `^3.12.2`), Node.js/npm, MySQL 8.0 và máy ảo Android hoặc điện thoại đã bật USB debugging.

Tải và giải nén mã nguồn, mở thư mục chứa `pubspec.yaml` trong VS Code. Các đường dẫn bên dưới đều tính từ thư mục này, không phụ thuộc ổ đĩa.

## 2. Nạp cơ sở dữ liệu

Mở MySQL Workbench, kết nối MySQL và chạy:

```sql
CREATE DATABASE IF NOT EXISTS quanlyduan
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Chọn **Server → Data Import → Import from Self-Contained File**, mở file `Database/quanlyduan.sql` trong mã nguồn đã tải về. Chọn **Default Target Schema = quanlyduan**, **Import Structure and Data**, rồi nhấn **Start Import**.

File này đã chứa các bảng và dữ liệu cần thiết. Chỉ nạp khi thiết lập ban đầu vì file có lệnh xóa và tạo lại bảng.

## 3. Cấu hình và chạy backend

Tạo hoặc chỉnh file `be/.env` theo MySQL trên máy:

```dotenv
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD="mat_khau_mysql_cua_ban"
DB_NAME=quanlyduan
JWT_SECRET=thay_bang_chuoi_bi_mat_rieng
NODE_ENV=development
OTP_DELIVERY=console
```

Thay tài khoản, mật khẩu và cổng MySQL cho đúng; thay `JWT_SECRET` bằng chuỗi bí mật riêng. Khi thử đăng ký/quên mật khẩu mà chưa dùng email, để trống `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`; mã OTP sẽ hiển thị trong terminal backend với cấu hình trên.

Mở terminal tại thư mục gốc dự án và chạy:

```powershell
cd be
npm install
node server.js
```

Giữ terminal này chạy. Kiểm tra server tại `http://localhost:3000/health`.

## 4. Đổi IP trong file xử lý đăng nhập

Mở **`lib/services/auth_service.dart`**, tìm **`AuthService.baseUrl`** và sửa dòng `return` trong nhánh Android:

```dart
return 'http://192.168.1.10:3000/api';
```

- **Điện thoại thật:** thay `192.168.1.10` bằng IPv4 của máy tính chạy backend (xem bằng lệnh `ipconfig`). Điện thoại và máy tính cần cùng mạng Wi-Fi/LAN.
- **Máy ảo Android Studio:** dùng `10.0.2.2` thay cho IP trên.
- **Flutter web trên máy chạy backend:** giữ `localhost` ở nhánh `kIsWeb`.

Chỉ sửa IP API tại file này vì các service dùng chung địa chỉ. Giữ cổng `3000` và đuôi `/api` theo cấu hình backend ở trên, rồi dừng và chạy lại ứng dụng. Nếu cấu hình Run/Debug cũ có `API_BASE_URL`, bỏ giá trị đó để dùng IP trong file.

## 5. Chạy ứng dụng

Mở máy ảo hoặc kết nối điện thoại qua USB. Mở terminal thứ hai tại thư mục chứa `pubspec.yaml` và chạy:

```powershell
flutter pub get
flutter run
```

Chọn thiết bị khi được hỏi. Nếu muốn chạy trên Chrome:

```powershell
flutter run -d chrome
```

Giữ MySQL và backend hoạt động trong suốt quá trình sử dụng. Nếu không kết nối được API, kiểm tra lại IP, mạng và quyền truy cập cổng 3000 trong Windows Firewall.

Chatbot cần `GEMINI_API_KEY`; thông báo đẩy cần cấu hình Firebase tương ứng ở ứng dụng và backend nếu muốn sử dụng các tính năng này.

## 6. Chạy và đăng nhập web admin

Sau khi nạp CSDL và chạy backend bằng `node server.js` như bước 3:

1. Mở trình duyệt và truy cập `http://localhost:3000/admin/login.html`.
2. Nhập email và mật khẩu tài khoản **admin** ở phần tài khoản thử nghiệm bên dưới.
3. Nhấn **Truy cập hệ thống**. Đăng nhập thành công sẽ chuyển đến trang quản trị `http://localhost:3000/admin/index.html`.

Web admin được phục vụ trực tiếp bởi backend, chỉ cần giữ MySQL và backend chạy; không cần chạy Flutter hay Live Server. Nếu truy cập từ máy khác cùng mạng, thay `localhost` bằng IP máy chạy backend. Web admin tự dùng địa chỉ API theo địa chỉ đang mở, không cần sửa IP trong mã web.

## 7. Tài khoản thử nghiệm

- user:
    tài khoản: famqi2003@gmail.com
    mật khẩu:qwe123

- admin:
    tài khoản: hongquy@gmail.com
    mật khẩu: qwe123
