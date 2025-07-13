## Работа с join'ами, статистикой

## Цель:
- знать и уметь применять различные виды join'ов
- строить и анализировать план выполенения запроса
- оптимизировать запрос
- уметь собирать и анализировать статистику для таблицы

### Задание:
- В результате выполнения ДЗ вы научитесь пользоваться
различными вариантами соединения таблиц.

```postgresql
-- Создадим таблицы
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT
);

INSERT INTO users (name, email) VALUES
('Иван Иванов', 'ivan@example.com'),
('Мария Петрова', 'maria@example.com'),
('Алексей Смирнов', 'aleksey@example.com'),
('Екатерина Новикова', 'ekaterina@example.com'),
('Дмитрий Кузнецов', 'dmitry@example.com');

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    amount NUMERIC(10,2),
    order_date DATE
);

INSERT INTO orders (user_id, amount, order_date) VALUES
(1, 1500.00, '2025-04-01'),
(1, 800.00, '2025-04-02'),
(2, 300.00, '2025-04-01'),
(3, 2000.00, '2025-04-03'),
(5, 950.00, '2025-04-03');

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name TEXT NOT NULL
);

INSERT INTO categories (category_name) VALUES
('Электроника'),
('Книги'),
('Одежда'),
('Продукты'),
('Мебель');

CREATE TABLE order_details (
    detail_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    category_id INT REFERENCES categories(category_id),
    quantity INT
);

INSERT INTO order_details (order_id, category_id, quantity) VALUES
(1, 1, 2),   -- Электроника, 2 шт.
(2, 3, 1),   -- Одежда, 1 шт.
(3, 2, 3),   -- Книги, 3 шт.
(4, 5, 1),   -- Мебель, 1 шт.
(5, 4, 5);   -- Продукты, 5 шт.
```

- В данном задании тренируются навыки:
написания запросов с различными типами соединений

Необходимо:
- Реализовать прямое соединение двух или более таблиц
```postgresql
-- Определить список самых покупающих пользователей за весь период
-- Возвращает только те строки, где есть совпадение по user_id в обеих таблицах — т.е. пользователи, у которых есть хотя бы один заказ.
SELECT
    u.name,
    sum(o.amount) as t_sum
FROM
    users u
INNER JOIN
    orders o ON u.user_id = o.user_id
GROUP BY u.name
ORDER BY t_sum DESC;

       name       |  t_sum
------------------+---------
 Иван Иванов      | 2300.00
 Алексей Смирнов  | 2000.00
 Дмитрий Кузнецов |  950.00
 Мария Петрова    |  300.00
(4 rows)
```
- Реализовать левостороннее (или правостороннее)
соединение двух или более таблиц
```postgresql
-- Получить всех пользователей, даже тех, у кого нет заказов
-- Возвращает всех пользователей. Если у пользователя нет заказов, поля из orders будут NULL.
SELECT 
    u.name,
    o.amount,
    o.order_date
FROM 
    users u
LEFT JOIN 
    orders o ON u.user_id = o.user_id;

        name        | amount  | order_date
--------------------+---------+------------
 Иван Иванов        | 1500.00 | 2025-04-01
 Иван Иванов        |  800.00 | 2025-04-02
 Мария Петрова      |  300.00 | 2025-04-01
 Алексей Смирнов    | 2000.00 | 2025-04-03
 Дмитрий Кузнецов   |  950.00 | 2025-04-03
 Екатерина Новикова |         |
(6 rows)

-- Получить все детали заказов, даже если нет связанных заказов или пользователей
-- RIGHT JOIN orders o - Сохраняет все строки из orders, даже если в order_details нет соответствующих записей
-- RIGHT JOIN users u - Сохраняет все строки из users, даже если у пользователя нет заказов или деталей заказов
SELECT 
    d.detail_id,
    o.order_id,
    u.user_id,
    u.name AS user_name,
    o.amount,
    d.quantity
FROM 
    order_details d
RIGHT JOIN 
    orders o ON d.order_id = o.order_id
RIGHT JOIN 
    users u ON o.user_id = u.user_id;

 detail_id | order_id | user_id |     user_name      | amount  | quantity
-----------+----------+---------+--------------------+---------+----------
         7 |        1 |       1 | Иван Иванов        | 1500.00 |        2
         8 |        2 |       1 | Иван Иванов        |  800.00 |        1
         9 |        3 |       2 | Мария Петрова      |  300.00 |        3
        10 |        4 |       3 | Алексей Смирнов    | 2000.00 |        1
        11 |        5 |       5 | Дмитрий Кузнецов   |  950.00 |        5
           |          |       4 | Екатерина Новикова |         |
(6 rows)
```
- Реализовать кросс соединение двух или более таблиц
```postgresql
-- Получить все возможные комбинации пользователей и категорий
-- Создаёт декартово произведение между всеми пользователями и всеми категориями. Полезно для генерации шаблонов или тестовых данных.
SELECT 
    u.name,
    c.category_name
FROM 
    users u
CROSS JOIN 
    categories c;

        name        | category_name
--------------------+---------------
 Иван Иванов        | Электроника
 Мария Петрова      | Электроника
 Алексей Смирнов    | Электроника
 Екатерина Новикова | Электроника
 Дмитрий Кузнецов   | Электроника
 Иван Иванов        | Книги
 Мария Петрова      | Книги
 Алексей Смирнов    | Книги
 Екатерина Новикова | Книги
 Дмитрий Кузнецов   | Книги
 Иван Иванов        | Одежда
 Мария Петрова      | Одежда
 Алексей Смирнов    | Одежда
 Екатерина Новикова | Одежда
 Дмитрий Кузнецов   | Одежда
 Иван Иванов        | Продукты
 Мария Петрова      | Продукты
 Алексей Смирнов    | Продукты
 Екатерина Новикова | Продукты
 Дмитрий Кузнецов   | Продукты
 Иван Иванов        | Мебель
 Мария Петрова      | Мебель
 Алексей Смирнов    | Мебель
 Екатерина Новикова | Мебель
 Дмитрий Кузнецов   | Мебель
(25 rows)
```
- Реализовать полное соединение двух или более таблиц
```postgresql
-- Получить всех пользователей и все заказы, даже если связи нет
-- Показать количество и сумму заказов, заменяя NULL на 0 для пользователей без заказов
SELECT 
    COALESCE(u.user_id, o.user_id) AS user_id,
    u.name,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.amount), 0.00) AS total_amount,
    ARRAY_AGG(DISTINCT o.order_date) AS order_dates
FROM 
    users u
FULL OUTER JOIN 
    orders o ON u.user_id = o.user_id
GROUP BY 
    COALESCE(u.user_id, o.user_id),
    u.name
ORDER BY 
    user_id;

 user_id |        name        | total_orders | total_amount |       order_dates
---------+--------------------+--------------+--------------+-------------------------
       1 | Иван Иванов        |            2 |      2300.00 | {2025-04-01,2025-04-02}
       2 | Мария Петрова      |            1 |       300.00 | {2025-04-01}
       3 | Алексей Смирнов    |            1 |      2000.00 | {2025-04-03}
       4 | Екатерина Новикова |            0 |         0.00 | {NULL}
       5 | Дмитрий Кузнецов   |            1 |       950.00 | {2025-04-03}
(5 rows)
```
- Реализовать запрос, в котором будут использованы
разные типы соединений
```postgresql
-- Получить пользователей, их заказы и категории товаров
-- Берёт всех пользователей (LEFT JOIN с orders) → чтобы не потерять тех, у кого нет заказов.
-- Только актуальные детали заказов (INNER JOIN с order_details) → потому что нам нужны только существующие детали.
-- Добавляет названия категорий (LEFT JOIN с categories) → могут быть неизвестные категории.
SELECT 
    u.name AS user_name,
    o.amount,
    c.category_name,
    od.quantity
FROM 
    users u
LEFT JOIN 
    orders o ON u.user_id = o.user_id
INNER JOIN 
    order_details od ON o.order_id = od.order_id
LEFT JOIN 
    categories c ON od.category_id = c.category_id;

    user_name     | amount  | category_name | quantity
------------------+---------+---------------+----------
 Иван Иванов      | 1500.00 | Электроника   |        2
 Иван Иванов      |  800.00 | Одежда        |        1
 Мария Петрова    |  300.00 | Книги         |        3
 Алексей Смирнов  | 2000.00 | Мебель        |        1
 Дмитрий Кузнецов |  950.00 | Продукты      |        5
(5 rows)
```
- Сделать комментарии на каждый запрос
- К работе приложить структуру таблиц, для которых
выполнялись соединения
> См. выше в DDL запросах.

Задание со звездочкой*
Придумайте 3 своих метрики на основе показанных представлений:
```postgresql
-- 1.Определить, какие таблицы чаще всего участвуют в операциях INSERT, UPDATE, DELETE.
-- Находит все RowExclusiveLock (обычно ставятся при INSERT, UPDATE, DELETE)
-- Группирует по имени таблицы. Считает количество таких блокировок → получаем "горячие" таблицы
-- Позволяет понять, где идёт наибольшая нагрузка.
SELECT 
    c.relname AS table_name,
    COUNT(*) AS lock_count
FROM 
    pg_locks l
JOIN 
    pg_class c ON l.relation = c.oid
WHERE 
    l.locktype = 'relation'
    AND l.mode = 'RowExclusiveLock'
    AND c.relkind = 'r'
GROUP BY 
    c.relname
ORDER BY 
    lock_count DESC
LIMIT 10;

-- 2.Оценить уровень конкуренции за ресурсы — сколько транзакций ждут освобождения блокировок.
-- Считает число активных транзакций. 
-- Считает число транзакций, которые ожидают событий (например, блокировок). Рассчитывает процент ожидающих транзакций
-- Высокий процент говорит о возможных проблемах с параллелизмом
-- Помогает диагностировать ситуации, когда транзакции зависают из-за блокировок.
WITH total_active AS (
    SELECT COUNT(*) AS total FROM pg_stat_activity WHERE state IS NOT NULL
),
waiting_procs AS (
    SELECT COUNT(*) AS waiting FROM pg_stat_activity WHERE wait_event IS NOT NULL
)
SELECT 
    ta.total AS active_connections,
    wp.waiting AS waiting_for_locks,
    ROUND((wp.waiting * 100.0) / ta.total, 2) AS percent_waiting
FROM 
    total_active ta,
    waiting_procs wp;


-- 3.Диагностика использования таблиц в конкретной схеме
-- seq_scan. частое сканирование может указывать на отсутствие индексов
-- n_tup_upd. rоличество обновлений — показывает "жизнеспособность" таблицы
-- n_tup_ins / del. Интенсивность изменений.
-- Размеры таблицы и индексов. Помогают определить "тяжёлые" таблицы.
SELECT 
    t.schemaname AS schema_name,
    t.relname AS table_name,
    a.rolname AS owner,
    t.seq_scan,
    t.seq_tup_read,
    t.n_tup_ins,
    t.n_tup_upd,
    t.n_tup_del,
    pg_size_pretty(pg_total_relation_size(t.relid)) AS total_size,
    pg_size_pretty(pg_table_size(t.relid)) AS table_size,
    pg_size_pretty(pg_indexes_size(t.relid)) AS index_size
FROM 
    pg_stat_all_tables t
JOIN 
    pg_class c ON t.relid = c.oid
JOIN 
    pg_authid a ON c.relowner = a.oid
WHERE t.schemaname = 'public'
ORDER BY 
    t.n_tup_upd DESC,
    t.n_tup_ins DESC;
```
