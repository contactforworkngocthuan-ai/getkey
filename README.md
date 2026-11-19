# Kxy🪽 — Cập nhật backend cho website GET KEY

Đây là mã nguồn của website GET KEY hiện tại. Website Admin sẽ được triển khai thành **một dự án Vercel riêng**, không nằm trong website GET KEY. Panel Admin gọi backend qua kết nối máy chủ–máy chủ có mã bí mật; mã này không được gửi xuống trình duyệt hoặc Roblox.

## Cập nhật website GET KEY đang dùng

1. Giữ nguyên dự án GET KEY và domain hiện tại.
2. Trong mã nguồn dự án GET KEY, thay file `api/[...route].js` bằng file cùng đường dẫn trong ZIP này, sau đó Redeploy dự án cũ.
3. Trong Vercel của website GET KEY, mở **Settings → Environment Variables**, thêm biến Production:
   - `KEY_ADMIN_API_TOKEN` = một chuỗi ngẫu nhiên riêng tư dài ít nhất 64 ký tự. Lưu lại để nhập chính xác cùng giá trị vào dự án Admin riêng.
4. Giữ nguyên `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` và `SIGNING_SECRET` đang dùng. Không tạo Redis mới cho website Admin.
5. Kiểm tra `https://DOMAIN-GETKEY.vercel.app/api/health`, kết quả cần có `storage: connected`.

Nếu không thể cập nhật source của dự án cũ và triển khai ZIP này thành dự án GET KEY mới, cần gắn lại domain GET KEY cũ cho dự án mới (hoặc cập nhật `BASE_URL` và URL trong Lua). Nếu URL thay đổi mà không cập nhật Lua, script Roblox sẽ vẫn gọi website cũ.

## Backend được cập nhật

- Key mới cấp qua Link4m/hCaptcha được ghi metadata và index vào cùng Upstash Redis để Admin có thể xem.
- Trình xác minh Roblox chấp nhận cả key có thời hạn và key vĩnh viễn.
- Thêm API riêng cho Admin: `GET/POST /api/admin/remote/keys` và `POST /api/admin/remote/revoke`.
- Các API này chỉ chấp nhận `Authorization: Bearer KEY_ADMIN_API_TOKEN`; không bật CORS cho trình duyệt.
- Website GET KEY không còn trang `admin.html`. Giao diện quản trị nằm trên website Vercel riêng.

## Lưu ý về key cũ

Các key được phát hành trước khi cập nhật backend có thể vẫn hoạt động, nhưng backend cũ không lưu chỉ mục metadata nên không thể tự động liệt kê hoặc thu hồi chúng trong panel mới. Key mới được cấp qua GET KEY sau lần cập nhật này và key do Admin tạo sẽ xuất hiện trong panel.

## Cấu hình

Website GET KEY giữ nguyên các biến `BASE_URL`, `LINK4M_API_KEY`, `HCAPTCHA_SITEKEY`, `HCAPTCHA_SECRET`, `SIGNING_SECRET`, `KEY_HOURS` và hai biến Upstash hiện tại. Chỉ thêm `KEY_ADMIN_API_TOKEN` như hướng dẫn trên. Không đưa token này vào HTML, Lua hoặc biến có tiền tố `NEXT_PUBLIC_`.
