-- BY RANGE - 1
-- создадим копию таблицы shop.order_main и секционируем её 
DROP SCHEMA IF EXISTS shop_copy CASCADE;
CREATE SCHEMA shop_copy;

/*
CREATE TABLE shop_copy.order_main
(
    order_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date
) PARTITION BY RANGE (order_date);
-- так нельзя! ( unique constraint on partitioned table must include all partitioning columns)
*/

CREATE TABLE shop_copy.order_main
(
    order_id        bigint GENERATED ALWAYS AS IDENTITY,    -- UNIQUE?
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date,
    
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

SELECT min(order_date), max(order_date) FROM shop.order_main;   --  2019-05-11 -> 2024-10-12
-- DELETE FROM shop.order_main WHERE order_date > '2024-01-01';

CREATE TABLE shop_copy.orders_2019_1 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2019-01-01') TO ('2019-04-01');
CREATE TABLE shop_copy.orders_2019_2 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2019-04-01') TO ('2019-07-01');
CREATE TABLE shop_copy.orders_2019_3 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2019-07-01') TO ('2019-10-01');
CREATE TABLE shop_copy.orders_2019_4 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2019-10-01') TO ('2020-01-01');
 
CREATE TABLE shop_copy.orders_2020_1 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2020-01-01') TO ('2020-04-01');
CREATE TABLE shop_copy.orders_2020_2 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2020-04-01') TO ('2020-07-01');
CREATE TABLE shop_copy.orders_2020_3 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2020-07-01') TO ('2020-10-01');
CREATE TABLE shop_copy.orders_2020_4 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2020-10-01') TO ('2021-01-01');

CREATE TABLE shop_copy.orders_2021_1 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2021-01-01') TO ('2021-04-01');
CREATE TABLE shop_copy.orders_2021_2 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2021-04-01') TO ('2021-07-01');
CREATE TABLE shop_copy.orders_2021_3 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2021-07-01') TO ('2021-10-01');
CREATE TABLE shop_copy.orders_2021_4 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2021-10-01') TO ('2022-01-01');

CREATE TABLE shop_copy.orders_2022_1 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2022-01-01') TO ('2022-04-01');
CREATE TABLE shop_copy.orders_2022_2 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2022-04-01') TO ('2022-07-01');
CREATE TABLE shop_copy.orders_2022_3 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2022-07-01') TO ('2022-10-01');
CREATE TABLE shop_copy.orders_2022_4 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2022-10-01') TO ('2023-01-01');

CREATE TABLE shop_copy.orders_2023_1 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2023-01-01') TO ('2023-04-01');
CREATE TABLE shop_copy.orders_2023_2 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2023-04-01') TO ('2023-07-01');
CREATE TABLE shop_copy.orders_2023_3 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2023-07-01') TO ('2023-10-01');
CREATE TABLE shop_copy.orders_2023_4 PARTITION OF shop_copy.order_main FOR VALUES FROM ('2023-10-01') TO ('2024-01-01');

--куда писать более поздние данные?
CREATE TABLE shop_copy.orders_other PARTITION OF shop_copy.order_main DEFAULT;
-- какие еще есть варианты?

CREATE INDEX ix1_order_main ON shop_copy.order_main USING btree (client_login);


-- копируем данные
INSERT INTO shop_copy.order_main
OVERRIDING SYSTEM VALUE
SELECT * FROM shop.order_main;

SELECT setval(pg_get_serial_sequence('shop_copy.order_main', 'order_id'), coalesce(max(order_id), 0) + 1)
FROM shop_copy.order_main;

VACUUM ANALYZE shop_copy.order_main;

-- секциониированная таблица:
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main WHERE order_date BETWEEN '2020-03-01' AND '2020-03-31';
-- Execution Time: 0.051 ms

-- монолитная таблица:
EXPLAIN ANALYZE
SELECT * FROM shop.order_main WHERE order_date BETWEEN '2020-03-01' AND '2020-03-31';
-- Execution Time: 0.075 ms

-- "Устранение" секций можно отключить
SET enable_partition_pruning = off;
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main WHERE order_date BETWEEN '2020-03-01' AND '2020-03-31';
RESET enable_partition_pruning;
SHOW enable_partition_pruning;
-- !
-- для запросов, не использующих фильтр по order_date секционирование не только бесполезно, но и вредно
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main WHERE client_login = 'Nowhere Man';
-- Execution Time: 0.110 ms

EXPLAIN ANALYZE
SELECT * FROM shop.order_main WHERE client_login = 'Nowhere Man';
-- Execution Time: 0.031 ms

/* ================================================================================================================== */
/*
    интересный момент:
    в триггере FOR EACH ROW TG_TABLE_NAME - имя секции,
    в триггере FOR EACH STATEMENT TG_TABLE_NAME - имя основной таблицы
*/
CREATE OR REPLACE FUNCTION shop_copy.ft_order_ins()
RETURNS trigger
AS
$ft$
BEGIN
    RAISE NOTICE 'level: %    table: %', TG_LEVEL, TG_TABLE_NAME;
    RETURN NULL;
END;
$ft$    LANGUAGE plpgsql
        SECURITY DEFINER;

CREATE OR REPLACE TRIGGER tr_order_ins_rw
AFTER INSERT
ON shop_copy.order_main
FOR EACH ROW
EXECUTE FUNCTION shop_copy.ft_order_ins();

CREATE OR REPLACE TRIGGER tr__order_ins_st
AFTER INSERT
ON shop_copy.order_main
FOR EACH STATEMENT
EXECUTE FUNCTION shop_copy.ft_order_ins();


INSERT INTO shop_copy.order_main (client_login, order_no)
VALUES ('Nowhere Man', '1998877');  -- значение TG_TABLE_NAME разное!


/*
    еще один интересный момент:
    доступ к секциям
*/
DROP USER IF EXISTS jimmy;
CREATE USER jimmy PASSWORD '1111';
GRANT CONNECT ON DATABASE book_shop TO jimmy;
GRANT USAGE ON SCHEMA shop_copy TO jimmy;
GRANT SELECT ON TABLE shop_copy.order_main TO jimmy; 

/*
psql -hlocalhost -dbook_shop -Ujimmy
SELECT * FROM shop_copy.order_main LIMIT 10;        --ОК
SELECT * FROM shop_copy.orders_2019_3 LIMIT 10;     -- УКК
*/
/* ================================================================================================================== */

-- ********************************************************************************************************************
-- Возможен другой подход к секционирования по диапазонам:
-- если бизнес работает с запросами вида
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE EXTRACT(YEAR FROM order_date) = 2019
  AND EXTRACT(QUARTER FROM order_date) = 2;

-- BY RANGE - 2
-- создадим копию таблицы shop.order_main и секционируем её 
DROP SCHEMA IF EXISTS shop_copy CASCADE;
CREATE SCHEMA shop_copy;


CREATE TABLE shop_copy.order_main
(
 --   order_id        bigint      GENERATED ALWAYS AS IDENTITY , -- PRIMARY KEY,    -- PRIMARY KEY constraints cannot be used when partition keys include expressions.
    order_id        bigint      GENERATED ALWAYS AS IDENTITY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date
) PARTITION BY RANGE (EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date));


CREATE OR REPLACE FUNCTION shop_copy.make_next_quart(p_y smallint, p_q smallint, OUT p_next_y smallint, OUT p_next_q smallint)
AS
$$
BEGIN
    p_next_y = p_y;
    p_next_q = p_q + 1;
    IF p_next_q > 4
    THEN
        p_next_q = 1;
        p_next_y = p_next_y + 1;
    END IF;
END;
$$  LANGUAGE plpgsql
    IMMUTABLE;

DO
$$
DECLARE
    v_year          smallint;
    v_quarter       smallint;
    v_year_next     smallint;
    v_quarter_next  smallint;
    query           text;
BEGIN
    FOR v_year, v_quarter
    IN (
        SELECT DISTINCT EXTRACT(YEAR FROM order_date) AS y, EXTRACT(QUARTER FROM order_date) AS q
        FROM shop.order_main
        ORDER BY EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date)
        )
    LOOP
        SELECT p_next_y, p_next_q INTO v_year_next, v_quarter_next FROM shop_copy.make_next_quart(v_year, v_quarter);
    
        query = format  ($frmt$
                        CREATE TABLE shop_copy.orders_%s_%s 
                        PARTITION OF shop_copy.order_main
                        FOR VALUES FROM (%s, %s) TO (%s, %s);
                        $frmt$,
                        v_year, v_quarter, v_year, v_quarter, v_year_next, v_quarter_next);

        RAISE NOTICE '%', query;
        EXECUTE query;

        -- PK придется создавать на партициях!
        query = format( $frmt$
                        ALTER TABLE shop_copy.orders_%s_%s ADD CONSTRAINT pk_orders_%s_%s PRIMARY KEY (order_id);
                        $frmt$,
                        v_year, v_quarter, v_year, v_quarter);

        RAISE NOTICE '%', query;
        EXECUTE query;

    END LOOP;
END;
$$;

CREATE TABLE shop_copy.orders_other PARTITION OF shop_copy.order_main DEFAULT;

INSERT INTO shop_copy.order_main
OVERRIDING SYSTEM VALUE
SELECT * FROM shop.order_main;

SELECT setval(pg_get_serial_sequence('shop_copy.order_main', 'order_id'), coalesce(max(order_id), 0) + 1)
FROM shop_copy.order_main;

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE EXTRACT(YEAR FROM order_date) = 2019
  AND EXTRACT(QUARTER FROM order_date) = 2;

----------------------------------------------------------------------------------------------------------------------------
-- вернёмся к 1-му варианту  
-- BY RANGE - 1
...

-- перенос архивных данных на медленный носитель
/*
mkdir users_tabspace
sudo chown postgres users_tabspace  
*/

-- добавим записей в таблицу
DO
$$
BEGIN
    FOR i IN 1 .. 14
    LOOP
        INSERT INTO shop_copy.order_main (client_login, order_no, order_date)
        SELECT  client_login,
                lpad(i::text, 2, 'A') || lpad((row_number() OVER ())::text, 10, '0'),
                order_date
        FROM shop_copy.order_main;

        COMMIT;

        RAISE NOTICE '%', i;       
    END LOOP; 
END
$$;



ALTER TABLE shop_copy.order_main DETACH PARTITION shop_copy.orders_2019_4;
-- можно удалить (будет быстрее, чем DELETE ... WHERE order_date BETWEEN ... и последующего VACUUM)

DROP TABLESPACE IF EXISTS arch_tab_space;
CREATE TABLESPACE arch_tab_space LOCATION '/home/student/users_tabspace';
ALTER TABLE shop_copy.orders_2019_4 SET TABLESPACE arch_tab_space;

DO
$$
DECLARE
    v_start timestamp = clock_timestamp();
BEGIN
    ALTER TABLE shop_copy.order_main ATTACH PARTITION shop_copy.orders_2019_4 FOR VALUES FROM ('2019-10-01') TO ('2020-01-01');
    RAISE NOTICE '%', clock_timestamp() - v_start;
END;
$$;
-- 00:00:00.261138

ALTER TABLE shop_copy.order_main DETACH PARTITION shop_copy.orders_2019_4;

ALTER TABLE shop_copy.orders_2019_4
   ADD CONSTRAINT check_for_part CHECK (order_date >= '2019-10-01'::date AND order_date <'2020-01-01'::date);  

DO
$$
DECLARE
    v_start timestamp = clock_timestamp();
BEGIN
    ALTER TABLE shop_copy.order_main ATTACH PARTITION shop_copy.orders_2019_4 FOR VALUES FROM ('2019-10-01') TO ('2020-01-01');
    RAISE NOTICE '%', clock_timestamp() - v_start;
END;
$$;
-- 00:00:00.000886

ALTER TABLE shop_copy.orders_2019_4 DROP CONSTRAINT check_for_part;  
------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------
-- Поведение FOREIGN KEYs при отсоединении секции:
------------------------------------------------------------------------------------------------------------------
CREATE TABLE tab
(
	id			integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	-- order_id	bigint REFERENCES shop_copy.order_main (order_id),
	order_id	bigint,
	order_date	date,
	str			text,
	
	FOREIGN KEY (order_id, order_date) REFERENCES shop_copy.order_main (order_id, order_date)
);

INSERT INTO shop_copy.order_main
OVERRIDING SYSTEM VALUE
SELECT * FROM shop.order_main;

SELECT setval(pg_get_serial_sequence('shop_copy.order_main', 'order_id'), coalesce(max(order_id), 0) + 1)
FROM shop_copy.order_main;

VACUUM ANALYZE shop_copy.order_main;

ALTER TABLE shop_copy.order_main DETACH PARTITION shop_copy.orders_2020_2;
ALTER TABLE shop_copy.order_main ATTACH PARTITION shop_copy.orders_2020_2 FOR VALUES FROM ('2020-04-01') TO ('2020-07-01');

SELECT count(1) FROM shop_copy.orders_2020_2;
SELECT * FROM shop_copy.orders_2020_2;

INSERT INTO tab(order_id, order_date, str) VALUES (199, '2020-04-07', '');
ALTER TABLE shop_copy.order_main DETACH PARTITION shop_copy.orders_2020_2;
------------------------------------------------------------------------------------------------------------------


-- BY LIST
DROP TABLE IF EXISTS shop_copy.order_main CASCADE;   -- при большом числе секций могут быть сюрпризы  

-- BY LIST
CREATE TABLE shop_copy.order_main
(
    order_id        bigint GENERATED ALWAYS AS IDENTITY, -- PRIMARY KEY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date
) PARTITION BY LIST (client_login);

CREATE TABLE shop_copy.order_main_00 PARTITION OF shop_copy.order_main FOR VALUES IN ('Ivan IV', 'Alexander I', 'Peter I');
CREATE TABLE shop_copy.order_main_01 PARTITION OF shop_copy.order_main FOR VALUES IN ('Марк Твен', 'O''Henry');
CREATE TABLE shop_copy.order_main_03 PARTITION OF shop_copy.order_main FOR VALUES IN ('Lyric', 'Itsme', 'Alex');
CREATE TABLE shop_copy.order_main_04 PARTITION OF shop_copy.order_main FOR VALUES IN ('Serge');
CREATE TABLE shop_copy.order_main_05 PARTITION OF shop_copy.order_main FOR VALUES IN ('Stasy');
CREATE TABLE shop_copy.order_main_06 PARTITION OF shop_copy.order_main FOR VALUES IN ('Т Ларина', 'О Ларина');
CREATE TABLE shop_copy.order_main_07 PARTITION OF shop_copy.order_main FOR VALUES IN ('mpd');
CREATE TABLE shop_copy.order_main_08 PARTITION OF shop_copy.order_main FOR VALUES IN ('Joury', 'Nowhere Man', 'Black Baron');
CREATE TABLE shop_copy.order_main_09 PARTITION OF shop_copy.order_main FOR VALUES IN ('someone');

CREATE TABLE shop_copy.order_main_10 PARTITION OF shop_copy.order_main DEFAULT;

-- копируем данные
INSERT INTO shop_copy.order_main
OVERRIDING SYSTEM VALUE
SELECT * FROM shop.order_main;

SELECT setval(pg_get_serial_sequence('shop_copy.order_main', 'order_id'), coalesce(max(order_id), 0) + 1)
FROM shop_copy.order_main;

-- добавим записей в таблицу
DO
$$
BEGIN
    FOR i IN 1 .. 11
    LOOP
        INSERT INTO shop_copy.order_main (client_login, order_no, order_date)
        SELECT  client_login,
                lpad(i::text, 2, 'A') || lpad((row_number() OVER ())::text, 10, '0'),
                order_date
        FROM shop_copy.order_main;

        COMMIT;

        RAISE NOTICE '%', i;       
    END LOOP; 
END
$$;

SELECT count(*) FROM shop_copy.order_main_04;   -- 167936

VACUUM ANALYZE shop_copy.order_main;

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main WHERE client_login = 'Serge' LIMIT 2;
-- Execution Time: 0.018 ms

-- монолит 
SELECT count(*) FROM shop.order_main WHERE client_login = 'Serge';  -- 82

EXPLAIN ANALYZE
SELECT * FROM shop.order_main WHERE client_login = 'Serge' LIMIT 2;
-- Execution Time: 0.043 ms (при том,что записей гораздо меньше)

-- поиск по полю, не являющемуся ключом секционирования
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_date = '2010-06-24';
-- Execution Time: 114.139 ms

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE client_login = 'Serge'
  AND order_date = '2010-06-24';
-- Execution Time: 27.770 ms

CREATE INDEX ix_order_main_order_date ON shop_copy.order_main USING btree (order_date);
-- создался на вcех секциях

-- а так:
DROP TABLE shop_copy.order_main_10;
CREATE TABLE shop_copy.order_main_10 PARTITION OF shop_copy.order_main DEFAULT;
--?
-- CREATE INDEX order_main_10_order_date_idx ON shop_copy.order_main_10 USING btree (order_date);

-- повторяем
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_date = '2010-06-24';
-- Execution Time: 114.139 ms
-- Почему по DEFAULT-секции (shop.order_main_10) идет Seq Scqn? Потому, что там пусто?

-- добавим записей в shop.order_main_10
INSERT INTO shop.client (client_login, firstname, lastname, email, delivery_addr)
VALUES ('New Client', 'abc', 'qwe', '1@2.3', '12345 qwer');

INSERT INTO shop_copy.order_main (client_login, order_no, order_date)
SELECT 'New Client', format('XX%s', lpad(i::text, 5, '0')), now()::date - (random()*720.)::integer
FROM generate_series(500, 1333) GS (i);

VACUUM ANALYZE shop_copy.order_main_10;

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_date = '2010-06-24';

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE client_login = 'Serge'
  AND order_date = '2010-06-24';
-- Execution Time: 0.021 ms

-- создание новой секции, как отдельной таблицы  
CREATE TABLE shop_copy.order_main_11
(
    order_id        bigint      GENERATED ALWAYS AS IDENTITY, -- PRIMARY KEY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date
);

INSERT INTO shop.client (client_login, firstname, lastname, email, delivery_addr)
VALUES ('Another Client', 'abc', 'qwe', '1@2.3', '12345 qwer');

INSERT INTO shop_copy.order_main_11 (client_login, order_no, order_date)
SELECT 'Another Client', format('XX%s', lpad(i::text, 5, '0')), now()::date - (random()*720.)::integer
FROM generate_series(500, 11333) GS (i);

ALTER TABLE shop_copy.order_main_11 ADD CONSTRAINT check_for_part CHECK (client_login = 'Another Client');
/*
ALTER TABLE shop_copy.order_main ATTACH PARTITION shop_copy.order_main_11 FOR VALUES IN ('Another Client');
EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_date = '2023-07-22'     -- где индекс?
*/
-- =========================================================================================================

-- BY HASH
DROP TABLE IF EXISTS shop_copy.order_main CASCADE;   -- при большом числе секций могут быть сюрпризы  

CREATE TABLE shop_copy.order_main
(
    order_id        bigint GENERATED ALWAYS AS IDENTITY, -- PRIMARY KEY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL,
    order_date      date        DEFAULT current_date
) PARTITION BY HASH (order_id);

CREATE TABLE shop_copy.order_main_00 PARTITION OF shop_copy.order_main FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE shop_copy.order_main_01 PARTITION OF shop_copy.order_main FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE shop_copy.order_main_02 PARTITION OF shop_copy.order_main FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE shop_copy.order_main_03 PARTITION OF shop_copy.order_main FOR VALUES WITH (MODULUS 4, REMAINDER 3);


-- копируем данные
INSERT INTO shop_copy.order_main
OVERRIDING SYSTEM VALUE
SELECT * FROM shop.order_main;

SELECT setval(pg_get_serial_sequence('shop_copy.order_main', 'order_id'), coalesce(max(order_id), 0) + 1)
FROM shop_copy.order_main;

-- добавим записей в таблицу
DO
$$
BEGIN
    FOR i IN 1 .. 11
    LOOP
        INSERT INTO shop_copy.order_main (client_login, order_no, order_date)
        SELECT  client_login,
                lpad(i::text, 2, 'A') || lpad((row_number() OVER ())::text, 10, '0'),
                order_date
        FROM shop_copy.order_main;

        COMMIT;

        RAISE NOTICE '%', i;       
    END LOOP; 
END
$$;

SELECT count(*) FROM shop_copy.order_main_02;   -- 383071

VACUUM ANALYZE shop_copy.order_main;




EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_id IN (2, 13, 18, 23, 25);

-- секционирование не работает!
CREATE FUNCTION temp_funct()
RETURNS SETOF integer
AS
$$
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
$$ LANGUAGE sql;

EXPLAIN ANALYZE
SELECT * FROM shop_copy.order_main
WHERE order_id IN (SELECT * FROM temp_funct());

EXPLAIN ANALYZE
WITH arr (id)
AS  (
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
    )
SELECT * FROM shop_copy.order_main
WHERE order_id IN (SELECT id FROM arr);

EXPLAIN ANALYZE
WITH arr (id)
AS MATERIALIZED (
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
    )
SELECT * FROM shop_copy.order_main
WHERE order_id IN (SELECT id FROM arr);

-- а так?
EXPLAIN ANALYZE
WITH arr (id)
AS  (
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
    )
SELECT *
FROM shop_copy.order_main M
INNER JOIN arr A ON A.id = M.order_id
WHERE A.id = 18;

-- а так???
ALTER TABLE shop_copy.order_main ADD COLUMN alt_id bigint;
UPDATE shop_copy.order_main SET alt_id = order_id;

EXPLAIN ANALYZE
WITH arr (id)
AS  (
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
    )
SELECT *
FROM shop_copy.order_main M
INNER JOIN arr A ON A.id = M.order_id
WHERE A.id = 18;    -- Ужас

EXPLAIN ANALYZE
WITH arr (id)
AS  (
    SELECT unnest(ARRAY[2, 13, 18, 23, 25])
    )
SELECT *
FROM shop_copy.order_main M
INNER JOIN arr A ON A.id = M.alt_id
WHERE A.id = 18
  AND M.order_id = 18
----------------------------------------------------------------------------------------------------




DELETE FROM shop_copy.big_table_01 WHERE id < 0;

DROP TABLE IF EXISTS shop_copy.big_table;

CREATE TABLE shop_copy.big_table
(
	id			integer GENERATED ALWAYS AS IDENTITY,
	part_key	integer NOT NULL,
	str			text,
	
	PRIMARY KEY (id, part_key)
) PARTITION BY LIST (part_key);

CREATE TABLE shop_copy.big_table_00 PARTITION OF shop_copy.big_table FOR VALUES IN (0, 1, 3);
CREATE TABLE shop_copy.big_table_01 PARTITION OF shop_copy.big_table FOR VALUES IN (2);
CREATE TABLE shop_copy.big_table_default PARTITION OF shop_copy.big_table DEFAULT;

INSERT INTO shop_copy.big_table (part_key, str)
SELECT (random() * 5)::integer, random()::text
FROM generate_series(1, 10000000);

SELECT count(1) FROM shop_copy.big_table_00;		-- 2498630
SELECT count(1) FROM shop_copy.big_table_01;		-- 1000023
SELECT count(1) FROM shop_copy.big_table_default;	-- 1501347

ALTER TABLE shop_copy.big_table DETACH PARTITION shop_copy.big_table_01;
ALTER TABLE shop_copy.big_table ATTACH PARTITION shop_copy.big_table_01 FOR VALUES IN (2);	-- 0.927s
--------------------------------------
ALTER TABLE shop_copy.big_table DETACH PARTITION shop_copy.big_table_01;
ALTER TABLE shop_copy.big_table_01 ADD CONSTRAINT ch CHECK (part_key = 2);
ALTER TABLE shop_copy.big_table ATTACH PARTITION shop_copy.big_table_01 FOR VALUES IN (2);
ALTER TABLE shop_copy.big_table_01 DROP CONSTRAINT ch;
--------------------------------------
ALTER TABLE shop_copy.big_table DETACH PARTITION shop_copy.big_table_01;
INSERT INTO shop_copy.big_table_01 (id, part_key, str) VALUES (-1, 2, '!');
ALTER TABLE shop_copy.big_table_01 ADD CONSTRAINT ch CHECK (part_key = 2);					-- 0.329s
ALTER TABLE shop_copy.big_table ATTACH PARTITION shop_copy.big_table_01 FOR VALUES IN (2);	-- 0.677s
ALTER TABLE shop_copy.big_table_01 DROP CONSTRAINT ch;
--------------------------------------
ALTER TABLE shop_copy.big_table DETACH PARTITION shop_copy.big_table_01;
-- выполняются операции по обслуживанию
ALTER TABLE shop_copy.big_table_01 ADD CONSTRAINT ch CHECK (part_key = 2) NOT VALID;		-- 0.009
ALTER TABLE shop_copy.big_table ATTACH PARTITION shop_copy.big_table_01 FOR VALUES IN (2);
ALTER TABLE shop_copy.big_table_01 DROP CONSTRAINT ch;
--------------------------------------
