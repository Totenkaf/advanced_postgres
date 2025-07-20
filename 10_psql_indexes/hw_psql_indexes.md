## Работа с индексами

## Цель:
- знать и уметь применять основные виды индексов PostgreSQL 
- строить и анализировать план выполнения запроса 
- уметь оптимизировать запросы для с использованием индексов

### Задание:
Описание/Пошаговая инструкция выполнения домашнего задания:

Создать индексы на БД, которые ускорят доступ к данным.
В данном задании тренируются навыки:
1. определения узких мест 
2. написания запросов для создания индекса 
3. оптимизации

Необходимо:
1. Создать индекс к какой-либо из таблиц вашей БД
```postgresql
-- Сгенерируем таблицы и данные в них для различных типов индексов:

-- -----------------------------
-- 1. B-Tree Индекс
-- -----------------------------
-- Цель: ускорение точных и диапазонных запросов
-- Ожидаемая оптимизация: быстрый поиск по age
-- -------------------------------------------
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    age INT
);

INSERT INTO users (name, age)
SELECT 'User ' || i, (RANDOM() * 100)::INT
FROM generate_series(1, 100000) AS i;

-- -----------------------------
-- 2. Full-text Search (tsvector + GIN)
-- -----------------------------
-- Цель: полнотекстовый поиск
-- Ожидаемая оптимизация: быстрый поиск по ключевым словам
-- -------------------------------------------

CREATE TABLE medium_messages (id int, body text, body_tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', body)) STORED);
CREATE TABLE words (id int, word text);
INSERT INTO words SELECT i, word
FROM generate_series(1, 20000) as i
CROSS JOIN LATERAL (
	SELECT string_agg(syllable, '')
	FROM (
		SELECT (string_to_array('th,he,an,er,in,re,nd,ou,en,on,ed,to,it,at,ha,ve,as,or,hi,ar,te,es,ver,hat,thi,tha,ent,ion,ith,ire,wit,eve,oul,uld,tio,ter,hen,era,hin,sho,ted,ome', ','))[floor(random() * 42) + 1]
		FROM generate_series(1, 3)
	) as f(syllable)
	WHERE i = i
) as f(word);

SELECT word FROM words ORDER BY random() LIMIT 10;

INSERT INTO medium_messages SELECT i, body
FROM generate_series(1, 100000) as i
CROSS JOIN LATERAL (
	SELECT string_agg(word, ' ') FROM (
		SELECT word FROM words ORDER BY random() LIMIT 30 -- ~250 letters
	) as words
	WHERE i = i
) as f(body);

-- -----------------------------
-- 3. Hash Индекс
-- -----------------------------
-- Цель: точные совпадения
-- Ожидаемая оптимизация: быстрая проверка на равенство
-- -------------------------------------------

CREATE TABLE logins (
    id SERIAL PRIMARY KEY,
    username TEXT
);

INSERT INTO logins (username)
SELECT 'user_' || md5(random()::text)
FROM generate_series(1, 100000) AS i;

-- -----------------------------
-- 4. Частичный и функциональный индекс
-- -----------------------------
-- Цель: ускорение подмножества данных и выражений
-- Ожидаемая оптимизация: уменьшение размера индекса и ускорение
-- -------------------------------------------

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT,
    total NUMERIC(10, 2),
    status TEXT
);

INSERT INTO orders (user_id, total, status)
SELECT 
    (RANDOM() * 1000)::INT + 1,
    (RANDOM() * 1000 + 10)::NUMERIC(10,2),
    (ARRAY['pending', 'processing', 'shipped', 'delivered', 'cancelled'])[ceil(random() * 5)]
FROM generate_series(1, 100000) AS i;

-- -----------------------------
-- 5. Составной индекс
-- -----------------------------
-- Цель: ускорение запросов по нескольким полям
-- Ожидаемая оптимизация: эффективный поиск по category + price
-- -------------------------------------------

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    category TEXT,
    price NUMERIC(10, 2)
);

INSERT INTO products (category, price)
SELECT 
    (ARRAY['books', 'electronics', 'clothing', 'furniture', 'toys'])[ceil(random() * 5)],
    (RANDOM() * 1000 + 10)::NUMERIC(10,2)
FROM generate_series(1, 100000) AS i;

-- 6. GiST Индекс для геоданных
-- -----------------------------
-- Цель: геопространственные запросы
-- Ожидаемая оптимизация: быстрый поиск в радиусе
-- -------------------------------------------

-- Убедитесь, что установлено расширение PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
-- В противном случае, выполните установку
-- sudo apt install postgis

indexdb=# \dx
                                List of installed extensions
  Name   | Version |   Schema   |                        Description
---------+---------+------------+------------------------------------------------------------
 plpgsql | 1.0     | pg_catalog | PL/pgSQL procedural language
 postgis | 3.5.3   | public     | PostGIS geometry and geography spatial types and functions
(2 rows)

CREATE TABLE cafes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    location GEOGRAPHY(Point, 4326)
);

INSERT INTO cafes (name, location)
SELECT 
    'Кафе ' || i,
    ST_SetSRID(
        ST_MakePoint(
            (RANDOM() * 2.5 + 37.6)::NUMERIC(9,6),  -- долгота в районе Москвы
            (RANDOM() * 0.85 + 55.7)::NUMERIC(9,6)   -- широта в районе Москвы
        ),
        4326
    )
FROM generate_series(1, 10000) AS i;

-- -----------------------------
-- 7. JOIN операции
-- -----------------------------
-- Цель: ускорение связей между таблицами
-- Ожидаемая оптимизация: быстрый поиск по внешнему ключу
-- -------------------------------------------

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name TEXT
);

CREATE TABLE orders_join (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    amount NUMERIC(10, 2)
);

-- 1000 пользователей
INSERT INTO customers (name)
SELECT 'Customer ' || i FROM generate_series(1, 1000) AS i;

-- 100 000 заказов
INSERT INTO orders_join (customer_id, amount)
SELECT 
    (RANDOM() * 999 + 1)::INT,
    (RANDOM() * 1000 + 10)::NUMERIC(10,2)
FROM generate_series(1, 100000) AS i;

```
2. Прислать текстом результат команды explain, в которой используется данный индекс
```postgresql
-- 1. B-Tree Индекс
EXPLAIN ANALYZE SELECT * FROM users WHERE age > 70;
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Seq Scan on users  (cost=0.00..1887.00 rows=29153 width=18) (actual time=0.016..9.013 rows=29392 loops=1)
   Filter: (age > 70)
   Rows Removed by Filter: 70608
 Planning Time: 0.073 ms
 Execution Time: 10.485 ms
(5 rows)
-- Видно, что без индекса делаем построчный перебор, что ожидаемо

-- Добавим B-Tree индекс на поле age
CREATE INDEX idx_users_age ON users USING BTREE (age);
ANALYZE users;

-- Проверим заново
EXPLAIN ANALYZE SELECT * FROM users WHERE age > 70;
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on users  (cost=334.23..1335.64 rows=29153 width=18) (actual time=1.179..5.480 rows=29392 loops=1)
   Recheck Cond: (age > 70)
   Heap Blocks: exact=637
   ->  Bitmap Index Scan on idx_users_age  (cost=0.00..326.94 rows=29153 width=0) (actual time=1.089..1.089 rows=29392 loops=1)
         Index Cond: (age > 70)
 Planning Time: 0.244 ms
 Execution Time: 6.721 ms
(7 rows)
-- Теперь пошли через индекс и bitmap, фактически выиграли почти в 2 раза по времени выполнения запроса, при этом время планирования запроса увеличилось, что опять же ожидаемо - время тратится на работу с индексом
```
3. Реализовать индекс для полнотекстового поиска
```postgresql
-- 2. Full-text Search (tsvector + GIN)
-- Заранее создал таблицу с полем ts, где было совершена токенизация вектора (с удалением стоп-слов (артикли и так далее) и приведение к инфинитиву - лемматизация)
EXPLAIN ANALYZE
SELECT body, ts_rank_cd(body_tsv, to_tsquery('abcd')) AS rank FROM medium_messages WHERE body_tsv @@ to_tsquery('abcd') ORDER BY rank DESC LIMIT 60;
                                                          QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=10000.26..10000.27 rows=1 width=36) (actual time=133.217..133.218 rows=0 loops=1)
   ->  Sort  (cost=10000.26..10000.27 rows=1 width=36) (actual time=133.215..133.216 rows=0 loops=1)
         Sort Key: (ts_rank_cd(body_tsv, to_tsquery('abcd'::text))) DESC
         Sort Method: quicksort  Memory: 25kB
         ->  Seq Scan on medium_messages  (cost=0.00..10000.25 rows=1 width=36) (actual time=133.210..133.210 rows=0 loops=1)
               Filter: (body_tsv @@ to_tsquery('abcd'::text))
               Rows Removed by Filter: 100000
 Planning Time: 0.089 ms
 Execution Time: 133.237 ms
(9 rows)

CREATE INDEX sm_fts_gin_idx ON medium_messages USING gin (body_tsv);
ANALYZE medium_messages;

EXPLAIN ANALYZE
SELECT body, ts_rank_cd(body_tsv, to_tsquery('abcd')) AS rank FROM medium_messages WHERE body_tsv @@ to_tsquery('abcd') ORDER BY rank DESC LIMIT 60;
                                                              QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=689.92..690.07 rows=60 width=259) (actual time=0.024..0.025 rows=0 loops=1)
   ->  Sort  (cost=689.92..690.32 rows=162 width=259) (actual time=0.023..0.023 rows=0 loops=1)
         Sort Key: (ts_rank_cd(body_tsv, to_tsquery('abcd'::text))) DESC
         Sort Method: quicksort  Memory: 25kB
         ->  Bitmap Heap Scan on medium_messages  (cost=18.18..684.32 rows=162 width=259) (actual time=0.018..0.019 rows=0 loops=1)
               Recheck Cond: (body_tsv @@ to_tsquery('abcd'::text))
               ->  Bitmap Index Scan on sm_fts_gin_idx  (cost=0.00..18.14 rows=162 width=0) (actual time=0.014..0.014 rows=0 loops=1)
                     Index Cond: (body_tsv @@ to_tsquery('abcd'::text))
 Planning Time: 0.393 ms
 Execution Time: 0.052 ms
(10 rows)
-- ого, для полнотекстового почти в 2500 раз улучшение!

-- 3. Hash Индекс
EXPLAIN ANALYZE
SELECT * FROM logins WHERE username = 'user_ced9afc9de0f1817ce35d4ae3d2f3305';
                                             QUERY PLAN
----------------------------------------------------------------------------------------------------
 Seq Scan on logins  (cost=0.00..2185.00 rows=1 width=42) (actual time=0.015..9.004 rows=1 loops=1)
   Filter: (username = 'user_ced9afc9de0f1817ce35d4ae3d2f3305'::text)
   Rows Removed by Filter: 99999
 Planning Time: 0.050 ms
 Execution Time: 9.018 ms
(5 rows)

-- Hash индекс
CREATE INDEX idx_logins_username_hash ON logins USING HASH (username);
ANALYZE logins;
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_logins_username_hash on logins  (cost=0.00..8.02 rows=1 width=42) (actual time=0.023..0.024 rows=1 loops=1)
   Index Cond: (username = 'user_ced9afc9de0f1817ce35d4ae3d2f3305'::text)
 Planning Time: 0.192 ms
 Execution Time: 0.043 ms
(4 rows)
-- Круто, ускорились почти в 210 раз!
```

4. Реализовать индекс на часть таблицы и индекс на поле с функцией
```postgresql
-- 4. Частичный и функциональный индекс
-- I. Частичный индекс
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'active' AND user_id = 1;

                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..2198.00 rows=1 width=23) (actual time=11.982..11.983 rows=0 loops=1)
   Filter: ((status = 'active'::text) AND (user_id = 1))
   Rows Removed by Filter: 100000
 Planning Time: 0.135 ms
 Execution Time: 11.999 ms
(5 rows)

-- Частичный индекс (только активные заказы)
CREATE INDEX idx_orders_active ON orders (user_id) WHERE status = 'active';
ANALYZE orders;

EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'active' AND user_id = 1;
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_orders_active on orders  (cost=0.12..8.14 rows=1 width=23) (actual time=0.004..0.004 rows=0 loops=1)
   Index Cond: (user_id = 1)
 Planning Time: 0.260 ms
 Execution Time: 0.024 ms
(4 rows)
-- Почти в 500 раз!

-- II. Функциональный индекс
EXPLAIN ANALYZE
SELECT * FROM orders WHERE UPPER(status) = 'SHIPPED';

                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..2198.00 rows=500 width=23) (actual time=0.025..35.258 rows=20026 loops=1)
   Filter: (upper(status) = 'SHIPPED'::text)
   Rows Removed by Filter: 79974
 Planning Time: 0.046 ms
 Execution Time: 36.091 ms
(5 rows)

CREATE INDEX idx_orders_upper_status ON orders (UPPER(status));
ANALYZE orders;
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on orders  (cost=226.00..1221.49 rows=19833 width=23) (actual time=0.783..4.257 rows=20026 loops=1)
   Recheck Cond: (upper(status) = 'SHIPPED'::text)
   Heap Blocks: exact=698
   ->  Bitmap Index Scan on idx_orders_upper_status  (cost=0.00..221.04 rows=19833 width=0) (actual time=0.687..0.688 rows=20026 loops=1)
         Index Cond: (upper(status) = 'SHIPPED'::text)
 Planning Time: 0.209 ms
 Execution Time: 5.103 ms
(7 rows)
```

5. Создать индекс на несколько полей 
```postgresql
-- 5. Составной индекс
EXPLAIN ANALYZE
SELECT * FROM products
WHERE category = 'books' AND price < 50;

                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Seq Scan on products  (cost=0.00..2119.00 rows=825 width=18) (actual time=0.072..15.832 rows=788 loops=1)
   Filter: ((price < '50'::numeric) AND (category = 'books'::text))
   Rows Removed by Filter: 99212
 Planning Time: 0.310 ms
 Execution Time: 15.886 ms
(5 rows)
-- оптимизировал запрос, поменям поля местами, странно ведь < 50 - диапазон

CREATE INDEX idx_products_category_price ON products (category, price);
ANALYZE products;

EXPLAIN ANALYZE
SELECT * FROM products
WHERE category = 'books' AND price < 50;
                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on products  (cost=24.69..688.91 rows=807 width=18) (actual time=0.207..0.852 rows=788 loops=1)
   Recheck Cond: ((category = 'books'::text) AND (price < '50'::numeric))
   Heap Blocks: exact=431
   ->  Bitmap Index Scan on idx_products_category_price  (cost=0.00..24.49 rows=807 width=0) (actual time=0.151..0.151 rows=788 loops=1)
         Index Cond: ((category = 'books'::text) AND (price < '50'::numeric))
 Planning Time: 0.361 ms
 Execution Time: 0.903 ms
(7 rows)
-- здесь видно, что он пошел по правильному пути и вначале поискал полное сравнение

DROP INDEX idx_products_category_price;
ANALYZE products;

CREATE INDEX idx_products_price_category ON products (price, category);
ANALYZE products;
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on products  (cost=112.51..776.53 rows=796 width=18) (actual time=0.360..0.809 rows=788 loops=1)
   Recheck Cond: ((price < '50'::numeric) AND (category = 'books'::text))
   Heap Blocks: exact=431
   ->  Bitmap Index Scan on idx_products_price_category  (cost=0.00..112.31 rows=796 width=0) (actual time=0.303..0.304 rows=788 loops=1)
         Index Cond: ((price < '50'::numeric) AND (category = 'books'::text))
 Planning Time: 0.141 ms
 Execution Time: 0.852 ms
(7 rows)
-- а здесь все равно пошел вначале по диапазону, при этом запрос по плану менее выгодный

-- 6. GiST Индекс для геоданных
-- ST_Buffer(geometry, distance) — создаёт буферную зону вокруг объекта (например, круг радиусом distance метров вокруг точки).
-- ST_Intersects(geometry, geometry) — проверяет, пересекаются ли два объекта.
-- Пример: найдем ближайшее кафе в 5 км от заданной точки
                                                                
EXPLAIN ANALYZE
SELECT name, ST_Distance(location, ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)) AS distance
FROM cafes
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326), 5000)
ORDER BY distance;

                                                              QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=33032.83..33032.83 rows=1 width=226) (actual time=20.443..20.453 rows=28 loops=1)
   Sort Key: (st_distance(location, '0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40'::geography, true))
   Sort Method: quicksort  Memory: 26kB
   ->  Seq Scan on cafes  (cost=0.00..33032.82 rows=1 width=226) (actual time=1.888..20.404 rows=28 loops=1)
         Filter: st_dwithin(location, '0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40'::geography, '5000'::double precision, true)
         Rows Removed by Filter: 9972
 Planning Time: 0.093 ms
 Execution Time: 20.483 ms
(8 rows)

                                                                                                                                        
CREATE INDEX idx_cafes_location ON cafes USING GIST (location);
ANALYZE cafes;

EXPLAIN ANALYZE
SELECT name, ST_Distance(location, ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)) AS distance
FROM cafes
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326), 5000)
ORDER BY distance;

                                                                  QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=698.26..698.27 rows=1 width=21) (actual time=0.273..0.275 rows=28 loops=1)
   Sort Key: (st_distance(location, '0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40'::geography, true))
   Sort Method: quicksort  Memory: 26kB
   ->  Bitmap Heap Scan on cafes  (cost=4.64..698.25 rows=1 width=21) (actual time=0.093..0.259 rows=28 loops=1)
         Filter: st_dwithin(location, '0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40'::geography, '5000'::double precision, true)
         Rows Removed by Filter: 21
         Heap Blocks: exact=41
         ->  Bitmap Index Scan on idx_cafes_location  (cost=0.00..4.64 rows=48 width=0) (actual time=0.024..0.024 rows=49 loops=1)
               Index Cond: (location && _st_expand('0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40'::geography, '5000'::double precision))
 Planning Time: 0.789 ms
 Execution Time: 0.339 ms
(11 rows)
-- выиграли почти в 60 раз

-- 7. JOIN операции
EXPLAIN ANALYZE
SELECT c.name, SUM(o.amount)
FROM customers c
JOIN orders_join o ON c.id = o.customer_id
GROUP BY c.name;

 HashAggregate  (cost=2334.11..2346.61 rows=1000 width=44) (actual time=57.138..57.369 rows=1000 loops=1)
   Group Key: c.name
   Batches: 1  Memory Usage: 577kB
   ->  Hash Join  (cost=29.50..1834.11 rows=100000 width=18) (actual time=0.325..32.306 rows=100000 loops=1)
         Hash Cond: (o.customer_id = c.id)
         ->  Seq Scan on orders_join o  (cost=0.00..1541.00 rows=100000 width=10) (actual time=0.021..9.336 rows=100000 loops=1)
         ->  Hash  (cost=17.00..17.00 rows=1000 width=16) (actual time=0.297..0.299 rows=1000 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 59kB
               ->  Seq Scan on customers c  (cost=0.00..17.00 rows=1000 width=16) (actual time=0.007..0.146 rows=1000 loops=1)
 Planning Time: 0.497 ms
 Execution Time: 57.466 ms
(11 rows)

CREATE INDEX idx_orders_customer_id ON orders_join (customer_id);
ANALYZE customers;
ANALYZE orders_join;

                                                           QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=2334.11..2346.61 rows=1000 width=44) (actual time=54.539..54.776 rows=1000 loops=1)
   Group Key: c.name
   Batches: 1  Memory Usage: 577kB
   ->  Hash Join  (cost=29.50..1834.11 rows=100000 width=18) (actual time=0.346..29.226 rows=100000 loops=1)
         Hash Cond: (o.customer_id = c.id)
         ->  Seq Scan on orders_join o  (cost=0.00..1541.00 rows=100000 width=10) (actual time=0.008..6.811 rows=100000 loops=1)
         ->  Hash  (cost=17.00..17.00 rows=1000 width=16) (actual time=0.330..0.331 rows=1000 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 59kB
               ->  Seq Scan on customers c  (cost=0.00..17.00 rows=1000 width=16) (actual time=0.009..0.132 rows=1000 loops=1)
 Planning Time: 0.335 ms
 Execution Time: 54.864 ms
(11 rows)
-- в моем случае оптимизатор все равно считает, что ему выгоднее пойти через seq scan
```
6. Написать комментарии к каждому из индексов 
7. Описать что и как делали и с какими проблемами столкнулись
