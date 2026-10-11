#!/bin/bash
set -euo pipefail

NETWORK="app-net"
VOLUME="db-data"
DB_CONTAINER="db-server"
APP_CONTAINER="app-container"
DB_PASSWORD="Postgres@12345"

echo "=== 1. Create network ==="
docker network inspect "$NETWORK" >/dev/null 2>&1 ||
    docker network create "$NETWORK"

echo "=== 2. Create volume ==="
docker volume inspect "$VOLUME" >/dev/null 2>&1 ||
    docker volume create "$VOLUME"

echo "=== 3. Start PostgreSQL ==="
if ! docker container inspect "$DB_CONTAINER" >/dev/null 2>&1; then
    docker run -d
        --name "$DB_CONTAINER"
        --network "$NETWORK"
        --restart unless-stopped
        -e POSTGRES_DB=appdb
        -e POSTGRES_USER=appuser
        -e POSTGRES_PASSWORD="$DB_PASSWORD"
        -v "$VOLUME":/var/lib/postgresql/data
        postgres:15-alpine
else
    docker start "$DB_CONTAINER" >/dev/null 2>&1 || true
fi

echo "=== 4. Wait for PostgreSQL ==="
until docker exec "$DB_CONTAINER" pg_isready -U appuser -d appdb >/dev/null 2>&1; do
    sleep 2
done

echo "=== 5. Initialize sample data ==="
docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U appuser -d appdb <<'SQL'
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

echo "=== 6. Start backend test container ==="
if ! docker container inspect "$APP_CONTAINER" >/dev/null 2>&1; then
    docker run -d
        --name "$APP_CONTAINER"
        --network "$NETWORK"
        --restart unless-stopped
        -e DB_HOST="$DB_CONTAINER"
        -e DB_PORT=5432
        -e DB_NAME=appdb
        -e DB_USER=appuser
        -e DB_PASSWORD="$DB_PASSWORD"
        alpine:3.21
        sh -c "apk add --no-cache postgresql-client busybox-extras >/dev/null && exec sleep infinity"
else
    docker start "$APP_CONTAINER" >/dev/null 2>&1 || true
fi

echo "=== 7. Test DNS ==="
docker exec "$APP_CONTAINER" ping -c 2 "$DB_CONTAINER"

echo "=== 8. Test database connection ==="
docker exec "$APP_CONTAINER" sh -c
'PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM students ORDER BY id;"'

echo "=== Completed ==="