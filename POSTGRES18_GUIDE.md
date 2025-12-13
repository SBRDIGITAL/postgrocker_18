# PostgreSQL 18: короткое руководство (postgrocker_18)

> Версия: PostgreSQL 18 · Клиент: asyncpg · ORM: SQLAlchemy 2.x (async) · Python 3.11+  
> Ориентир: официальные изменения PostgreSQL 18 (release notes/docs).

## 1. Что нового (сверхкратко)
- Async I/O: сервер сам параллелит/объединяет чтения; быстрее seq/bitmap scan и VACUUM.
- Skip Scan: индекс `(a,b,c)` можно использовать без условия по `a`; план выбирает сервер.
- Параллельное создание GIN: быстрее JSONB/FTS/trgm с `max_parallel_maintenance_workers`.
- Virtual generated columns: вычисляются на чтении (VIRTUAL), можно `STORED`.
- `uuidv7()`: упорядочен по времени, лучшая локальность вставок; `uuidv4()` теперь встроен.
- Перенос статистики при `pg_upgrade`: меньше деградации, но всё равно сделайте `ANALYZE`.
- Безопасность: SCRAM по умолчанию; добавлен OAuth метод; расширены TLS-настройки.
- Wire protocol 3.2: эволюция; драйверы могут оставаться на 3.0.

## 2. Запуск БД (наш compose)
```bash
cp .env.template .env          # задайте свой пароль
docker compose up -d
docker compose ps
```
- Данные: именованный том `postgrocker_18_postgrocker_data` → `/var/lib/postgresql`.
- Конфиги: `postgresql.conf`, `pg_hba.conf` монтируются read-only.
- Безопасность: SCRAM-SHA-256, слушаем только `127.0.0.1`.

## 3. Подключение
```bash
# psql с хоста
psql -h 127.0.0.1 -p 5435 -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# из контейнера
docker compose exec postgrocker_18 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

## 4. Фичи 18 — как попробовать
### 4.1 Async I/O
`postgresql.conf` (уже смонтирован):
```conf
io_method = 'worker'          # 'io_uring' если доступно
io_workers = 6
effective_io_concurrency = 64
maintenance_io_concurrency = 32
```

### 4.2 Skip Scan
```sql
CREATE TABLE orders(
  region int, country text, order_id bigint,
  PRIMARY KEY(region, country, order_id)
);
EXPLAIN SELECT * FROM orders WHERE country='DE' AND order_id BETWEEN 100 AND 200;
-- план может показать Index Skip Scan
```

### 4.3 Параллельный GIN
```sql
SET max_parallel_maintenance_workers = 4;
CREATE INDEX CONCURRENTLY idx_docs_fts
  ON documents USING GIN (to_tsvector('simple', content));
```

### 4.4 Virtual columns
```sql
CREATE TABLE products (
  id bigserial PRIMARY KEY,
  price numeric NOT NULL,
  vat numeric NOT NULL,
  total numeric GENERATED ALWAYS AS (price * (1+vat)) VIRTUAL
);
```

### 4.5 UUIDv7
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- для uuidv4 при необходимости
CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  payload jsonb NOT NULL,
  created_at timestamptz DEFAULT now()
);
```
Python (asyncpg):
```python
import asyncpg, asyncio, json
DSN="postgresql://user:pass@127.0.0.1:5435/postgrocker_db"
async def add_event(data):
    conn = await asyncpg.connect(DSN)
    rid = await conn.fetchval(
        """INSERT INTO events(payload) VALUES($1) RETURNING id::text""",
        json.dumps(data),
    )
    await conn.close()
    return rid
```

### 4.6 Перенос статистики
После `pg_upgrade` всё равно:
```sql
ANALYZE;
```
Проверьте ключевые планы/`pg_stat_all_tables`.

### 4.7 Auth (локально)
`pg_hba.conf`: SCRAM, только localhost. TLS не включён (по требованию). Пароль — из `.env`.

## 5. Что в нашем `postgresql.conf`
- I/O: `io_method`, `io_workers`, `effective_io_concurrency`, `maintenance_io_concurrency`.
- Логи + ротация: `logging_collector=on`, `log_destination='csvlog'`, `log_directory='/var/log/postgresql'`, `log_rotation_age=1d`, `log_rotation_size=200MB`.
- Параллельность: `max_worker_processes`, `max_parallel_workers_per_gather`, `max_parallel_workers`.
- Безопасность: `hba_file='/etc/postgresql/pg_hba.conf'`, `listen_addresses='127.0.0.1'`.

## 6. Бенчмарк UUIDv4 vs UUIDv7
- Скрипт: `uuid_bench.py`.
- Запуск:
```bash
PYTHONUNBUFFERED=1 python uuid_bench.py --dsn postgresql://user:pass@127.0.0.1:5435/postgrocker_db \
  --n 200000 --batch-size 1000
```
- Метрики: rows/sec, `pg_relation_size`, `pg_indexes_size`, опционально pgstattuple.

## 7. Мини-FAQ
- Логи? → `./db_logs` (файлы) или `docker compose logs -f postgrocker_18`.
- Снести данные? → `docker compose down -v` (удалит том с БД).
- Сменить порт? → `POSTGRES_PORT` в `.env` и порт в `docker-compose.yml`.
- Включить io_uring? → образ с liburing + `io_method='io_uring'` в `postgresql.conf`.

## 8. Официальные ссылки
- Release Notes 18: https://www.postgresql.org/docs/18/release-18.html
- Async I/O / ресурсы: https://www.postgresql.org/docs/18/runtime-config-resource.html
- Generated columns: https://www.postgresql.org/docs/18/ddl-generated-columns.html
- UUID: https://www.postgresql.org/docs/18/functions-uuid.html
- GIN: https://www.postgresql.org/docs/18/gin.html
- pg_upgrade + статистика: https://www.postgresql.org/docs/18/pgupgrade.html
- Auth / pg_hba: https://www.postgresql.org/docs/18/auth-pg-hba-conf.html
