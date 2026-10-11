# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu

- Tạo Custom Bridge Network có tên `app-net` để các container giao tiếp nội bộ thông qua DNS.
- Tạo Named Volume có tên `db-data` để lưu trữ dữ liệu PostgreSQL bền vững.
- Khởi chạy PostgreSQL container và backend container bằng Docker CLI.
- Cấu hình backend kết nối database thông qua hostname `db-server`.
- Kiểm tra khả năng phân giải DNS giữa các container.
- Kiểm chứng Data Persistence sau khi xóa và tạo lại container database.

## 2. Môi trường thực hành

- Hệ điều hành: Ubuntu Server trên VPS.
- Công cụ: Docker Engine và Docker CLI.
- Database image: `postgres:15-alpine`.
- Backend thử nghiệm: `alpine:3.21`.
- Tên Network: `app-net`.
- Tên Volume: `db-data`.
- Tên Database Container: `db-server`.
- Tên Backend Container: `app-container`.
- Database: `appdb`.
- Database User: `appuser`.

**Lưu ý:** Backend trong bài thực hành là container thử nghiệm có công cụ `ping` và PostgreSQL client để kiểm tra kết nối mạng và database, không phải ứng dụng Web API hoàn chỉnh.

## 3. Tạo Custom Bridge Network

Tạo mạng Docker riêng để các container giao tiếp với nhau:

```bash
docker network create app-net
```

Kiểm tra network:

```bash
docker network ls | grep app-net
docker network inspect app-net
```

**Kết quả mong đợi:** Network `app-net` được tạo thành công và có driver `bridge`.

## 4. Tạo Named Volume

Tạo volume để lưu dữ liệu PostgreSQL:

```bash
docker volume create db-data
```

Kiểm tra volume:

```bash
docker volume ls | grep db-data
docker volume inspect db-data
```

**Kết quả mong đợi:** Named Volume `db-data` tồn tại và có thể được mount vào container database.

## 5. Khởi chạy PostgreSQL Database Container

Khởi chạy PostgreSQL 15 và gắn volume `db-data` vào thư mục lưu trữ dữ liệu:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  --restart unless-stopped \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD='Postgres@12345' \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Kiểm tra container:

```bash
docker ps
docker logs db-server
```

Chờ database sẵn sàng:

```bash
until docker exec db-server pg_isready -U appuser -d appdb; do
  sleep 2
done
```

**Kết quả mong đợi:** Container `db-server` chạy thành công, PostgreSQL sẵn sàng nhận kết nối và dữ liệu được lưu trong Named Volume `db-data`.

## 6. Tạo dữ liệu mẫu trong PostgreSQL

Tạo bảng `students` và thêm ba bản ghi mẫu:

```bash
docker exec -i db-server psql -U appuser -d appdb <<'SQL'
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL
);

INSERT INTO students (full_name, email)
VALUES
    ('Nguyen Van An', 'an@example.com'),
    ('Tran Thi Binh', 'binh@example.com'),
    ('Le Minh Cuong', 'cuong@example.com')
ON CONFLICT (email) DO NOTHING;

SELECT * FROM students ORDER BY id;
SQL
```

**Kết quả mong đợi:** Bảng `students` được tạo và chứa ba bản ghi mẫu.

## 7. Khởi chạy Backend Container

Khởi chạy container thử nghiệm tham gia network `app-net` và truyền các biến môi trường kết nối database:

```bash
docker run -d \
  --name app-container \
  --network app-net \
  --restart unless-stopped \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD='Postgres@12345' \
  alpine:3.21 \
  sh -c "apk add --no-cache postgresql-client busybox-extras >/dev/null && exec sleep infinity"
```

Kiểm tra trạng thái:

```bash
docker ps
```

**Kết quả mong đợi:** Hai container `db-server` và `app-container` cùng chạy trên network `app-net`.

## 8. Kiểm tra DNS Resolution

Sử dụng lệnh ping từ backend container đến database container:

```bash
docker exec -it app-container ping -c 2 db-server
```

Kiểm tra thông tin các container trong network:

```bash
docker network inspect app-net
```

**Kết quả mong đợi:**

- Hostname `db-server` được phân giải thành địa chỉ IP nội bộ.
- Các gói ping nhận được phản hồi.
- Hai container được kết nối với network `app-net`.

## 9. Kiểm tra kết nối PostgreSQL từ Backend

Thực hiện truy vấn database từ `app-container`:

```bash
docker exec app-container sh -c \
'PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM students ORDER BY id;"'
```

**Kết quả mong đợi:** Backend kết nối thành công tới PostgreSQL thông qua hostname `db-server` và truy vấn được dữ liệu trong bảng `students`.

## 10. Kiểm thử Data Persistence

### 10.1. Thêm dữ liệu mới

Thêm một sinh viên mới:

```bash
docker exec db-server psql -U appuser -d appdb -c \
"INSERT INTO students (full_name, email) VALUES ('Pham Thi Dung', 'dung@example.com');"
```

Kiểm tra dữ liệu trước khi xóa container:

```bash
docker exec db-server psql -U appuser -d appdb -c \
"SELECT * FROM students ORDER BY id;"
```

**Kết quả mong đợi:** Bảng có bốn bản ghi, bao gồm sinh viên `Pham Thi Dung`.

### 10.2. Xóa cứng Database Container

Xóa container database:

```bash
docker rm -f db-server
```

Kiểm tra Named Volume vẫn tồn tại:

```bash
docker volume ls | grep db-data
```

Volume `db-data` không bị xóa cùng container.

### 10.3. Tạo lại Database Container

Khởi chạy container mới với cùng cấu hình database và gắn lại volume cũ:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  --restart unless-stopped \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD='Postgres@12345' \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Chờ PostgreSQL sẵn sàng:

```bash
until docker exec db-server pg_isready -U appuser -d appdb; do
  sleep 2
done
```

### 10.4. Xác minh dữ liệu sau khi tạo lại container

```bash
docker exec db-server psql -U appuser -d appdb -c \
"SELECT * FROM students ORDER BY id;"
```

Kiểm tra volume được mount đúng:

```bash
docker inspect db-server \
  --format '{{range .Mounts}}{{println .Name "->" .Destination}}{{end}}'
```

**Kết quả mong đợi:**

- Dữ liệu trong bảng `students` vẫn còn sau khi tạo lại container.
- Bản ghi `dung@example.com` vẫn tồn tại.
- Volume `db-data` được mount vào `/var/lib/postgresql/data`.

Điều này chứng minh dữ liệu được lưu trữ độc lập với vòng đời của container database.

## 11. Các lệnh kiểm tra tổng hợp

```bash
docker network ls | grep app-net
docker volume ls | grep db-data
docker network inspect app-net
docker ps
docker exec -it app-container ping -c 2 db-server
docker inspect db-server \
  --format '{{range .Mounts}}{{println .Name "->" .Destination}}{{end}}'
```

## 12. Kết luận

Qua bài thực hành, đã sử dụng Docker CLI để tạo Custom Bridge Network và Named Volume, khởi chạy PostgreSQL container cùng backend container, cấu hình kết nối database bằng hostname `db-server` và kiểm tra DNS Resolution.

Kết quả kiểm thử Data Persistence cho thấy dữ liệu PostgreSQL vẫn được giữ nguyên sau khi xóa cứng container database và tạo lại container với cùng Named Volume `db-data`.

Các file nộp bài:

- `commands.sh`: Script thực hiện các thao tác Docker theo yêu cầu.
- `README.md`: Tài liệu mô tả quy trình thực hiện và kiểm tra kết quả.

Đường dẫn nộp bài: `homework/session_10/ex4/`