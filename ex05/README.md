# Bài 5: Tự động hóa điều phối đa dịch vụ với Docker Compose & File .env

## 1. Mục tiêu

- Sử dụng Docker Compose CLI v2 để điều phối nhiều dịch vụ.
- Khởi chạy đồng thời dịch vụ backend và PostgreSQL.
- Sử dụng file `.env` để quản lý biến môi trường.
- Sử dụng `.env.example` làm mẫu cấu hình.
- Cấu hình `depends_on`, `networks` và `volumes`.
- Thực hành khởi chạy, kiểm tra log và dừng dịch vụ.

## 2. Cấu trúc thư mục

```text
ex5/
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

File `.env` được tạo tại máy triển khai từ `.env.example` và không đưa vào kho Git.

## 3. Cấu hình môi trường

Tạo file cấu hình thực tế từ file mẫu:

```bash
cp .env.example .env
nano .env
```

Cập nhật `DB_PASSWORD` thành mật khẩu mạnh do người triển khai tự chọn.

Các biến môi trường được sử dụng:

| Biến | Ý nghĩa |
|---|---|
| `DB_NAME` | Tên cơ sở dữ liệu |
| `DB_USER` | Tài khoản PostgreSQL |
| `DB_PASSWORD` | Mật khẩu PostgreSQL |
| `PORT` | Cổng backend trên máy chủ |

## 4. Kiểm tra cấu hình Docker Compose

Kiểm tra phiên bản Docker Compose:

```bash
docker compose version
```

Kiểm tra cấu hình trước khi khởi chạy:

```bash
docker compose config
```

## 5. Khởi chạy các dịch vụ

```bash
docker compose up -d
```

Kiểm tra trạng thái container:

```bash
docker compose ps
```

Xem log của các dịch vụ:

```bash
docker compose logs
```

Theo dõi log liên tục:

```bash
docker compose logs -f
```

Nhấn `Ctrl + C` để thoát chế độ theo dõi log. Thao tác này không dừng các container.

## 6. Kiểm tra hoạt động

Kiểm tra backend qua cổng đã cấu hình:

```bash
curl http://localhost:8081
```

Kiểm tra backend phân giải tên dịch vụ database qua mạng Docker:

```bash
docker compose exec backend ping -c 2 database
```

Kiểm tra kết nối PostgreSQL từ backend:

```bash
docker compose exec backend sh -c \
'PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT current_database(), current_user;"'
```

Kết quả truy vấn thành công cho thấy backend có thể kết nối PostgreSQL bằng cấu hình môi trường.

## 7. Dừng các dịch vụ

```bash
docker compose down
```

Lệnh này dừng và xóa các container cùng network do Compose tạo ra. Named volume `pgdata` vẫn được giữ lại để bảo toàn dữ liệu.

Không sử dụng `docker compose down -v` nếu cần giữ dữ liệu PostgreSQL.

## 8. Kiểm tra file nộp

```bash
ls -la
```

Đảm bảo thư mục có đủ bốn file:

- `docker-compose.yml`
- `.env.example`
- `.gitignore`
- `README.md`

File `.env` được sử dụng khi triển khai nhưng không được đưa lên Git.

## 9. Kết luận

Bài thực hành sử dụng Docker Compose để quản lý dịch vụ backend và PostgreSQL, cấu hình biến môi trường, kiểm tra kết nối giữa các dịch vụ và sử dụng named volume để duy trì dữ liệu sau khi container bị xóa.
