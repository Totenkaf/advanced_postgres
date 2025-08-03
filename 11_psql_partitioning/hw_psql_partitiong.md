## Секционирование таблицы

## Цель:
- научиться выполнять секционирование таблиц в PostgreSQL;
- повысить производительность запросов и упростив управление данными;

### Задание:
На основе готовой базы данных примените один из методов секционирования в зависимости от структуры данных.
https://postgrespro.ru/education/demodb

```bash
# Скачал архив с большой таблицей demo_big.zip
# Залил на удаленный сервер
scp -r -i <key>> ~/demo_big.zip ubuntu@<fip>:~/
# Перенес под пользователя postgres
sudo mv /var/lib/postgresql
# Разархивировал
sudo apt install unzip && unzip demo_big.zip
# Залил данные в БД
sudo su postgres && psql -U postgres -d postgres -f demo_big.sql
# В итоге получил таблицу demo
postgres@psql-ubuntu-test:/home/ubuntu$ psql demo
psql (17.5 (Ubuntu 17.5-1.pgdg22.04+1))
Type "help" for help.

demo=# \conninfo
You are connected to database "demo" as user "postgres" via socket in "/var/run/postgresql" at port "5432".
demo=# \l+
                                                                                   List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate |  Ctype  | Locale | ICU Rules |   Access privileges   |  Size   | Tablespace |                Description
-----------+----------+----------+-----------------+---------+---------+--------+-----------+-----------------------+---------+------------+--------------------------------------------
 demo      | postgres | UTF8     | libc            | C.UTF-8 | C.UTF-8 |        |           |                       | 2640 MB | pg_default |
 postgres  | postgres | UTF8     | libc            | C.UTF-8 | C.UTF-8 |        |           |                       | 7843 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | libc            | C.UTF-8 | C.UTF-8 |        |           | =c/postgres          +| 7321 kB | pg_default | unmodifiable empty database
           |          |          |                 |         |         |        |           | postgres=CTc/postgres |         |            |
 template1 | postgres | UTF8     | libc            | C.UTF-8 | C.UTF-8 |        |           | =c/postgres          +| 7547 kB | pg_default | default template for new databases
           |          |          |                 |         |         |        |           | postgres=CTc/postgres |         |            |
(4 rows)

demo=# \dt+ bookings.*
                                            List of relations
  Schema  |      Name       | Type  |  Owner   | Persistence | Access method |  Size  |    Description
----------+-----------------+-------+----------+-------------+---------------+--------+-------------------
 bookings | aircrafts       | table | postgres | permanent   | heap          | 16 kB  | Самолеты
 bookings | airports        | table | postgres | permanent   | heap          | 48 kB  | Аэропорты
 bookings | boarding_passes | table | postgres | permanent   | heap          | 456 MB | Посадочные талоны
 bookings | bookings        | table | postgres | permanent   | heap          | 105 MB | Бронирования
 bookings | flights         | table | postgres | permanent   | heap          | 21 MB  | Рейсы
 bookings | seats           | table | postgres | permanent   | heap          | 96 kB  | Места
 bookings | ticket_flights  | table | postgres | permanent   | heap          | 547 MB | Перелеты
 bookings | tickets         | table | postgres | permanent   | heap          | 386 MB | Билеты
(8 rows)
```

Шаги выполнения домашнего задания:

1. Анализ структуры данных:
Ознакомьтесь с таблицами базы данных, особенно с таблицами bookings, tickets, ticket_flights, flights, boarding_passes, seats, airports, aircrafts.
Определите, какие данные в таблице bookings или других таблицах имеют логическую привязку к диапазонам, по которым можно провести секционирование (например, дата бронирования, рейсы).
```bash
Таблица bookings содержит дату бронирования (book_date timestamp with time zone).
Таблица flights содержит время вылета/прилёта (scheduled_departure).

Обе таблицы активно используются в аналитических и операционных запросах.
Данные охватывают исторический период (месяцы/год), что делает их идеальными кандидатами для секционирования по диапазону дат.
```

2. Выбор таблицы для секционирования:
Основной акцент делается на секционировании таблицы bookings. Но вы можете выбрать и другие таблицы, если видите в этом смысл для оптимизации производительности (например, flights, boarding_passes).
Обоснуйте свой выбор: почему именно эта таблица требует секционирования? Какой тип данных является ключевым для секционирования?
```bash
Высокий объём данных (в demo-big — более миллиона бронирований).
Для аналитики по авиаперелетам и составлению отчетности о прибылях и убытках и в принципе успешности бизнеса, всегда интересно смотреть на временные диапазоны, например, количество бронирований в конкретную дату, количество перелетов и др.
Данные растут со временем — идеально подходит для секционирования по времени.
```

3. Определение типа секционирования:
Определитесь с типом секционирования, которое наилучшим образом подходит для ваших данных:
- По диапазону (например, по дате бронирования или дате рейса).
- По списку (например, по пунктам отправления или по номерам рейсов).
- По хэшированию (для равномерного распределения данных).
```bash
book_date поле уже содержит в себе подсказку - это временной тип данных, а для него интереснее всего использовать RANGE:
- данные логически группируются по времени;
- запросы часто фильтруют по дате брони;
```

4. Создание секционированной таблицы:
Преобразуйте таблицу в секционированную с выбранным типом секционирования.
Например, если вы выбрали секционирование по диапазону дат бронирования, создайте секции по месяцам или годам.

Поскольку в исходной БД bookings уже существует как обычная таблица:
```bash
1. Переименуем старую таблицу.
2. Создадим новую — секционированную.
3. Создадим секции по месяцам.
4. Перенесём данные.
```

```postgresql
-- Переименуем существующую таблицу
ALTER TABLE bookings.bookings RENAME TO bookings_old;

-- Создаём новую секционированную таблицу
CREATE TABLE bookings.bookings (
    book_ref CHAR(6),
    book_date TIMESTAMP WITH TIME ZONE NOT NULL,
    total_amount NUMERIC NOT NULL,
    -- В уникальное ограничение должен быть включен столбец партицинирования!
    PRIMARY KEY(book_ref, book_date)
) PARTITION BY RANGE (book_date);

-- Также в моем bookings_old есть FOREIGN KEY
demo=# \d bookings.bookings_old
                      Table "bookings.bookings_old"
    Column    |           Type           | Collation | Nullable | Default
--------------+--------------------------+-----------+----------+---------
 book_ref     | character(6)             |           | not null |
 book_date    | timestamp with time zone |           | not null |
 total_amount | numeric(10,2)            |           | not null |
Indexes:
    "bookings_pkey" PRIMARY KEY, btree (book_ref)
Referenced by:
    TABLE "bookings.tickets" CONSTRAINT "tickets_book_ref_fkey" FOREIGN KEY (book_ref) REFERENCES bookings.bookings_old(book_ref)

-- Глянем минимальные и максимальные существующие даты
demo=# SELECT min(book_date), max(book_date) FROM bookings.bookings;
          min           |          max
------------------------+------------------------
 2015-09-18 17:16:00+00 | 2016-10-13 14:00:00+00
(1 row)

-- Теперь создадим партиции на основе диапазона: месяцев здесь немного, поэтому разобьем на их основе.
CREATE TABLE bookings.bookings_2015_09 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2015-09-01') TO ('2015-10-01');

CREATE TABLE bookings.bookings_2015_10 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2015-10-01') TO ('2015-11-01');

CREATE TABLE bookings.bookings_2015_11 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2015-11-01') TO ('2015-12-01');

CREATE TABLE bookings.bookings_2015_12 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2015-12-01') TO ('2016-01-01');

CREATE TABLE bookings.bookings_2016_01 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-01-01') TO ('2016-02-01');

CREATE TABLE bookings.bookings_2016_02 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-02-01') TO ('2016-03-01');

CREATE TABLE bookings.bookings_2016_03 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-03-01') TO ('2016-04-01');

CREATE TABLE bookings.bookings_2016_04 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-04-01') TO ('2016-05-01');

CREATE TABLE bookings.bookings_2016_05 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-05-01') TO ('2016-06-01');

CREATE TABLE bookings.bookings_2016_06 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-06-01') TO ('2016-07-01');

CREATE TABLE bookings.bookings_2016_07 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-07-01') TO ('2016-08-01');

CREATE TABLE bookings.bookings_2016_08 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-08-01') TO ('2016-09-01');

CREATE TABLE bookings.bookings_2016_09 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-09-01') TO ('2016-10-01');

CREATE TABLE bookings.bookings_2016_10 PARTITION OF bookings.bookings
    FOR VALUES FROM ('2016-10-01') TO ('2016-11-01');

-- для всех будущих записей
CREATE TABLE bookings.bookings_other PARTITION OF bookings.bookings DEFAULT;
```

5. Миграция данных:
Перенесите существующие данные из исходной таблицы в секционированную структуру.
Убедитесь, что все данные правильно распределены по секциям.
```postgresql
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
-- для переписывания последовательных значений первичных ключей
OVERRIDING SYSTEM VALUE
SELECT book_ref, book_date, total_amount
FROM bookings.bookings_old;

-- подготовим таблицу
VACUUM ANALYZE bookings.bookings;

-- Восстановим внешний ключ (так как теперь на bookings составной, а таблица tickets смотрит на старую таблицу со старым первичным ключом)
ALTER TABLE bookings.tickets RENAME TO tickets_old;

CREATE TABLE bookings.tickets (
    ticket_no CHAR(13) PRIMARY KEY,
    book_ref CHAR(6) NOT NULL,
    passenger_id VARCHAR(20) NOT NULL,
    passenger_name TEXT NOT NULL,
    contact_data JSONB,
    book_date TIMESTAMP WITH TIME ZONE NOT NULL,  -- добавим book_date для связи
    FOREIGN KEY (book_ref, book_date) REFERENCES bookings.bookings (book_ref, book_date)
        ON UPDATE CASCADE ON DELETE CASCADE
);

INSERT INTO bookings.tickets (ticket_no, book_ref, passenger_id, passenger_name, contact_data, book_date)
SELECT t.ticket_no, t.book_ref, t.passenger_id, t.passenger_name, t.contact_data, b.book_date
FROM bookings.tickets_old t
JOIN bookings.bookings_old b ON t.book_ref = b.book_ref;

-- Восстановим также ссылку на ticket_flights
ALTER TABLE bookings.ticket_flights
DROP CONSTRAINT ticket_flights_ticket_no_fkey;

ALTER TABLE bookings.ticket_flights
ADD CONSTRAINT ticket_flights_ticket_no_fkey
    FOREIGN KEY (ticket_no)
    REFERENCES bookings.tickets (ticket_no)
    ON UPDATE CASCADE
    ON DELETE CASCADE;
```

6. Оптимизация запросов:
Проверьте, как секционирование влияет на производительность запросов. Выполните несколько выборок данных до и после секционирования для оценки времени выполнения.
Оптимизируйте запросы при необходимости (например, добавьте индексы на ключевые столбцы).
```postgresql
-- Запрос: общая сумма бронирований за сентябрь 2016
EXPLAIN ANALYZE
SELECT SUM(total_amount)
FROM bookings.bookings_old
WHERE book_date >= '2016-09-01' AND book_date < '2016-10-01';

                                                                              QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
Finalize Aggregate  (cost=27852.99..27853.00 rows=1 width=32) (actual time=2931.249..2948.273 rows=1 loops=1)
   ->  Gather  (cost=27852.77..27852.98 rows=2 width=32) (actual time=2930.882..2948.261 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=26852.77..26852.78 rows=1 width=32) (actual time=2867.163..2867.164 rows=1 loops=3)
               ->  Parallel Seq Scan on bookings_old  (cost=0.00..26682.44 rows=68132 width=6) (actual time=0.028..2858.437 rows=55428 loops=3)
                     Filter: ((book_date >= '2016-09-01 00:00:00+00'::timestamp with time zone) AND (book_date < '2016-10-01 00:00:00+00'::timestamp with time zone))
                     Rows Removed by Filter: 648275
 Planning Time: 3.634 ms
 Execution Time: 2948.310 ms
(10 rows)

-- Запрос: общая сумма бронирований за сентябрь 2016
EXPLAIN ANALYZE
SELECT SUM(total_amount)
FROM bookings.bookings
WHERE book_date >= '2016-09-01' AND book_date < '2016-10-01';
                                                                              QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=3771.83..3771.84 rows=1 width=32) (actual time=32.356..36.979 rows=1 loops=1)
   ->  Gather  (cost=3771.71..3771.82 rows=1 width=32) (actual time=32.345..36.969 rows=2 loops=1)
         Workers Planned: 1
         Workers Launched: 1
         ->  Partial Aggregate  (cost=2771.71..2771.72 rows=1 width=32) (actual time=21.970..21.971 rows=1 loops=2)
               ->  Parallel Seq Scan on bookings_2016_09 bookings  (cost=0.00..2527.22 rows=97795 width=6) (actual time=0.017..12.618 rows=83142 loops=2)
                     Filter: ((book_date >= '2016-09-01 00:00:00+00'::timestamp with time zone) AND (book_date < '2016-10-01 00:00:00+00'::timestamp with time zone))
 Planning Time: 0.294 ms
 Execution Time: 37.009 ms
(9 rows)
-- очевидно, что пошли сразу в нужную партицию и выполнили агрегацию данных уже только в ней. выиграли почти в 80 раз
```

7. Тестирование решения:
Протестируйте секционирование, выполняя несколько запросов к секционированной таблице.
Проверьте, что операции вставки, обновления и удаления работают корректно.

```postgresql
-- Проверка вставки. Должно попасть в bookings_2016_10
INSERT INTO bookings.bookings (book_ref, book_date, total_amount)
VALUES ('TEST01', '2016-10-14', 50000.00);

demo=# select * from bookings.bookings_2016_10 where book_ref = 'TEST01';
 book_ref |       book_date        | total_amount
----------+------------------------+--------------
 TEST01   | 2016-10-14 00:00:00+00 |     50000.00
(1 row)

demo=# select * from bookings.bookings_2016_09 where book_ref = 'TEST01';
 book_ref | book_date | total_amount
----------+-----------+--------------
(0 rows)

-- Проверка обновления
UPDATE bookings.bookings SET total_amount = 60000.00 WHERE book_ref = 'TEST01';
demo=# select * from bookings.bookings_2016_10 where book_ref = 'TEST01';
 book_ref |       book_date        | total_amount
----------+------------------------+--------------
 TEST01   | 2016-10-14 00:00:00+00 |     60000.00
(1 row)

-- Проверка удаления
DELETE FROM bookings.bookings WHERE book_ref = 'TEST01';
demo=# select * from bookings.bookings_2016_10 where book_ref = 'TEST01';
 book_ref | book_date | total_amount
----------+-----------+--------------
(0 rows)
```

8. Документирование:
Добавьте комментарии к коду, поясняющие выбранный тип секционирования и шаги его реализации.
Опишите, как секционирование улучшает производительность запросов и как оно может быть полезно в реальных условиях.
```bash
Все запросы смотри по пунктам выше
```

9. Формат сдачи:
- SQL-скрипты с реализованным секционированием.
- Краткий отчет с описанием процесса и результатами тестирования.
- Пример запросов и результаты до и после секционирования.

10. Критерии оценки:
- Корректность секционирования – таблица должна быть разделена логично и эффективно.
- Выбор типа секционирования – обоснование выбранного типа (например, секционирование по диапазону дат рейсов или по месту отправления/прибытия).
- Работоспособность решения – код должен успешно выполнять секционирование без ошибок.
- Оптимизация запросов – после секционирования, запросы к таблице должны быть оптимизированы (например, быстрее выполняться для конкретных диапазонов).
- Комментирование – код должен содержать поясняющие комментарии, объясняющие выбор секционирования и основные шаги.