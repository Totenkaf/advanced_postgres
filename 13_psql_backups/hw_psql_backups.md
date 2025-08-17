## Бэкапы

## Цель:
- применить логический бэкап. Восстановиться из бэкапа.

### Задание:
1. Создаем ВМ/докер c ПГ. 
2. Создаем БД, схему и в ней таблицу.
3. Заполним таблицы авто-сгенерированными 100 записями.
```postgresql
CREATE DATABASE backup_test;
\c backup_test

CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE backup.products AS
SELECT id AS product_id, id * 10 * random() AS price, 'Product ' || id AS product
FROM generate_series(1, 100) AS id;

SELECT * FROM backup.products LIMIT 5;
 product_id |       price        |  product
------------+--------------------+-----------
          1 |  8.527855595739592 | Product 1
          2 | 16.347417121763353 | Product 2
          3 |  7.941329836817676 | Product 3
          4 |  35.54673248813556 | Product 4
          5 | 28.563473467631294 | Product 5
(5 rows)
```
4. Под линукс пользователем Postgres создадим каталог для бэкапов
```bash
sudo su postgres
mkdir -p /tmp/backup
```
5. Сделаем логический бэкап используя утилиту COPY
```postgresql
-- как csv
COPY backup.products TO '/tmp/backup/products.csv' WITH CSV HEADER DELIMITER ',';

postgres@psql-ubuntu-test:/tmp/backup$ cat products.csv
product_id,price,product
1,8.527855595739592,Product 1
2,16.347417121763353,Product 2
3,7.941329836817676,Product 3
4,35.54673248813556,Product 4
5,28.563473467631294,Product 5
6,50.29613686223162,Product 6
7,6.3790524355725235,Product 7
8,70.23171076392451,Product 8
9,80.06216825439124,Product 9
10,59.22455067278571,Product 10
11,42.039786492963245,Product 11
12,27.3400003493526,Product 12
```
6. Восстановим во 2-ю таблицу данные из бэкапа.
```postgresql
CREATE TABLE backup.products_restore (
    product_id int,
    price numeric,
    product text
);

COPY backup.products_restore FROM '/tmp/backup/products.csv' WITH CSV HEADER DELIMITER ',';

backup_test=# SELECT * FROM backup.products_restore LIMIT 5;
 product_id |       price        |  product
------------+--------------------+-----------
          1 |  8.527855595739592 | Product 1
          2 | 16.347417121763353 | Product 2
          3 |  7.941329836817676 | Product 3
          4 |  35.54673248813556 | Product 4
          5 | 28.563473467631294 | Product 5
(5 rows)
```
7. Используя утилиту pg_dump создадим бэкап в кастомном сжатом формате двух таблиц
```postgresql
-- создадим вторую таблицу
CREATE TABLE backup.categories AS
SELECT id AS category_id, 'Category ' || id AS name
FROM generate_series(1, 100) AS id;
```

```bash
# запустим pg_dump
pg_dump -U postgres -d backup_test \
  -t 'backup.products' \
  -t 'backup.categories' \
  --format=custom \
  --file=/tmp/backup/backup_custom.dump

ls -la /tmp/backup/backup_custom.dump
-rw-rw-r-- 1 postgres postgres 3358 Aug 17 13:25 /tmp/backup/backup_custom.dump
```
8. Используя утилиту pg_restore восстановим в новую БД только вторую таблицу!
```postgresql
-- новая БД
CREATE DATABASE restore_test;
\c restore_test
```

```bash
# посмотрим структуру дампа
pg_restore -l /tmp/backup/backup_custom.dump
;
; Archive created at 2025-08-17 13:25:34 UTC
;     dbname: backup_test
;     TOC Entries: 8
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 17.5 (Ubuntu 17.5-1.pgdg22.04+1)
;     Dumped by pg_dump version: 17.5 (Ubuntu 17.5-1.pgdg22.04+1)
;
;
; Selected TOC Entries:
;
220; 1259 18169 TABLE backup categories postgres
218; 1259 18159 TABLE backup products postgres
3342; 0 18169 TABLE DATA backup categories postgres
3341; 0 18159 TABLE DATA backup products postgres
# отметим, что у нас не попали DDL запросы для создания структуры БД
```

```postgresql
-- создадим схему в новой БД
CREATE SCHEMA backup;
```

```bash
pg_restore -d restore_test --table=categories /tmp/backup/backup_custom.dump
```

```postgresql
-- проверим
restore_test=# 
select * from backup.categories limit 5;
 category_id |    name
-------------+------------
           1 | Category 1
           2 | Category 2
           3 | Category 3
           4 | Category 4
           5 | Category 5
(5 rows)
-- все верно
```