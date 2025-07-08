\\-- ЭТО не SQL-команды, выполняем в терминале linux или командной строке Windows
--          psql -dpostgres
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- #1       Базы данных
-- просмотр баз данных кластера:
SELECT * FROM pg_database;
-- Или команды psql \l и \l+

-- только "интересные" столбцы
SELECT  datname, encoding, pg_encoding_to_char(encoding),
        dattablespace, datistemplate, datallowconn
FROM pg_database;

-- #1.1     -- Создание базы данных с атрибутами по умолчанию
CREATE DATABASE ddl_otus;
-- #1.2
ALTER DATABASE ddl_otus RENAME TO otus_ddl; 

-- Переключение на созданную БД: 
-- \c otus_ddl


-- #2     Создание табличного пространства
/* 
   ЭТО не SQL-команды, выполняем в терминале linux или командной строке Windows
            mkdir /home/master/pg_ext_data
		    или
			mkdir /home/student/pg_ext_data
			
            sudo chown postgres:postgres /home/master/pg_ext_data
			или
sudo chown postgres:postgres /home/student/pg_ext_data
*/
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CREATE TABLESPACE ext_tabspace LOCATION '/home/student/pg_ext_data';

SELECT * FROM pg_tablespace
-- или команды psql \db и \db+


-- #3     Создание схемы
CREATE SCHEMA ddl_pract;

-- Просмотр
SELECT * FROM pg_namespace;
-- Или команды psql \dn и \dn+

-- #4 Создание таблицы (в схеме по умолчанию)
CREATE TABLE table_one
(
    id_one      integer PRIMARY KEY,
    some_text   text
) tablespace ext_tabspace;

CREATE TABLE table_two
(
    id_two      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_one      integer REFERENCES table_one (id_one),
    some_text   text UNIQUE
) tablespace ext_tabspace;

INSERT INTO table_one (id_one, some_text) VALUES (1, 'one'), (2, 'two');

INSERT INTO table_two (id_one, some_text) VALUES (1, '1-1'), (1, '1-2'), (2, '2-1');

SELECT * FROM table_one;

-- #5 Создание таблицы из результатов запроса
CREATE TABLE table_three
AS
SELECT T1.id_one, T1.some_text AS first_text, T2.id_two, T2.some_text AS second_text
FROM table_one T1
INNER JOIN table_two T2 ON T2.id_one = T1.id_one

-- копирование СТРУКТУРЫ таблицы
CREATE TABLE copy_of_table_two (LIKE table_two);

-- #6
-- Перенесем таблицу в схему ddl_pract
ALTER TABLE table_one SET SCHEMA ddl_pract;

SELECT * FROM table_one;    -- Почему не работает?

SELECT * FROM ddl_pract.table_one;

-- схема, имя которой совпадает с именем пользователя ():
SELECT current_user;
CREATE SCHEMA master;
CREATE TABLE master.table_one
(
    single_field    integer;
);

CREATE TABLE table_one
(
    single_field    integer;
);
-- \dt \dt ddl_pract.* \dt *.*

SET search_path = ddl_pract, public;
SHOW search_path;
SELECT * FROM table_one;

DROP TABLE master.table_one;

-- попробуем удалить табличное пространство
DROP TABLESPACE ext_tabspace;		-- почему не получилось?

-- перенесем таблицы из ext_tabspace в pg_default
-- SELECT pg_relation_filepath('ddl_pract.table_one');
ALTER TABLE ddl_pract.table_one SET tablespace pg_default;
ALTER TABLE public.table_two SET tablespace pg_default;
-- SELECT pg_relation_filepath('ddl_pract.table_one');


-- Теперь получится:
DROP TABLESPACE ext_tabspace;

-- Преобразуем базу данных в шаблон
\c postgres
ALTER DATABASE otus_ddl IS_TEMPLATE true;

-- ALTER DATABASE otus_ddl ALLOW_CONNECTIONS false;

-- Переименуем во избежании недоразумений...
ALTER DATABASE otus_ddl RENAME TO otus_ddl_template;

SELECT  datname, encoding, pg_encoding_to_char(encoding),
        dattablespace, datistemplate, datallowconn
FROM pg_database;


/* 
 возможно придется выполнить
SELECT pg_terminate_backend(pid) FROM pg_catalog.pg_stat_activity WHERE datname = 'otus_ddl';
*/
-- и создадим новую ДБ
CREATE DATABASE ddl_pract TEMPLATE otus_ddl_template;
-- \c ddl_pract

SELECT * FROM ddl_pract.table_one;
----------------------------------------------------------------------------------------------------

-- #7	секционирование таблиц
-- создадим отдельную схему
DROP SCHEMA IF EXISTS part_data CASCADE;
CREATE SCHEMA IF NOT EXISTS part_data;

-- Секционирование по диапазону:
CREATE TABLE part_data.large_log
(
	id			integer GENERATED ALWAYS AS IDENTITY,
	log_date	date NOT NULL,
	some_text	text

	,CONSTRAINT pk_large_log PRIMARY KEY (id, log_date)
) PARTITION BY RANGE (log_date);

CREATE TABLE part_data.large_log_2021_11
PARTITION OF part_data.large_log
FOR VALUES FROM ('2021-11-01') TO ('2021-12-01');

CREATE TABLE part_data.large_log_2021_12
PARTITION OF part_data.large_log
FOR VALUES FROM ('2021-12-01') TO ('2022-01-01');

CREATE TABLE part_data.large_log_2022_01
PARTITION OF part_data.large_log
FOR VALUES FROM ('2022-01-01') TO ('2022-01-31');

INSERT INTO part_data.large_log (log_date, some_text)
VALUES  ('2021-11-01', 'раз'),
        ('2021-11-10', 'два'),
        ('2021-11-30', 'три'),
        ('2021-12-30', 'четыре'),
        ('2021-12-31', 'пять'),
        ('2022-01-01', 'шесть'),
        ('2022-01-01', 'семь');

SELECT * FROM  part_data.large_log;

SELECT * FROM part_data.large_log_2021_11;
SELECT * FROM part_data.large_log_2021_12;
SELECT * FROM part_data.large_log_2022_01;

EXPLAIN
SELECT * FROM  part_data.large_log WHERE log_date = '2021-12-10'    -- Поиск данных производится только в large_log_2021_12

INSERT INTO part_data.large_log (log_date, some_text) VALUES  ('2020-10-10', '???');                    -- ошибка!
INSERT INTO part_data.large_log_2022_01 (log_date, some_text) VALUES  ('2020-10-10', '???');            -- ошибка!
INSERT INTO part_data.large_log_2022_01 (id, log_date, some_text) VALUES  (999, '2020-10-10', '???');	-- ошибка!

-- attach, detach
CREATE TABLE part_data.large_log_2021_10 (LIKE part_data.large_log);

INSERT INTO part_data.large_log_2021_10 (id, log_date, some_text)
VALUES  (991, '2021-10-20', 'восемь'),
        (992, '2021-10-21', 'девять'),
        (993, '2021-10-22', 'десять');

ALTER TABLE part_data.large_log
ATTACH PARTITION part_data.large_log_2021_10
FOR VALUES FROM ('2021-10-01') TO ('2021-11-01');

ALTER TABLE part_data.large_log
DETACH PARTITION part_data.large_log_2021_10
----------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
DROP SCHEMA IF EXISTS part_data CASCADE;
CREATE SCHEMA IF NOT EXISTS part_data;

-- Секционирование по списку:
CREATE TABLE part_data.large_log
(
	id			integer GENERATED ALWAYS AS IDENTITY,
	log_item_id	integer NOT NULL,
	some_text	text

	,CONSTRAINT pk_large_log PRIMARY KEY (id, log_item_id)
) PARTITION BY LIST (log_item_id);

CREATE TABLE part_data.large_log_137
PARTITION OF part_data.large_log
FOR VALUES IN (1, 3, 7);

CREATE TABLE part_data.large_log_24
PARTITION OF part_data.large_log
FOR VALUES IN (2, 4);

CREATE TABLE part_data.large_log_5
PARTITION OF part_data.large_log
FOR VALUES IN (5);

INSERT INTO part_data.large_log (log_item_id, some_text)
VALUES  (1, 'раз'),
        (1, 'два'),
        (1, 'три'),
        (2, 'четыре'),
        (3, 'пять'),
        (4, 'шесть'),
        (7, 'семь');

SELECT * FROM part_data.large_log;

SELECT * FROM part_data.large_log_137;
SELECT * FROM part_data.large_log_24;
SELECT * FROM part_data.large_log_5;

INSERT INTO part_data.large_log (log_item_id, some_text) VALUES (99, '???');       -- ошибка!
------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
DROP SCHEMA IF EXISTS part_data CASCADE;
CREATE SCHEMA IF NOT EXISTS part_data;

-- Секционирование по хэшу:
CREATE TABLE part_data.large_log
(
	id			integer GENERATED ALWAYS AS IDENTITY,
	log_cost	integer NOT NULL,
	some_text	text

	,CONSTRAINT pk_large_log PRIMARY KEY (id, log_cost)
) PARTITION BY HASH (log_cost);

CREATE TABLE part_data.large_log_00
PARTITION OF part_data.large_log
FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE part_data.large_log_01
PARTITION OF part_data.large_log
FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE part_data.large_log_02
PARTITION OF part_data.large_log
FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE part_data.large_log_03
PARTITION OF part_data.large_log
FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO part_data.large_log (log_cost, some_text)
VALUES  (90, 'раз'),
        (92, 'два'),
        (93, 'три'),
        (94, 'четыре'),
        (95, 'пять'),
        (96, 'шесть'),
        (97, 'семь');

SELECT * FROM part_data.large_log;

SELECT * FROM part_data.large_log_00;
SELECT * FROM part_data.large_log_01;
SELECT * FROM part_data.large_log_02;
SELECT * FROM part_data.large_log_03;
------------------------------------------------------------------------------------------------------------------------


-- #8 Представления
CREATE VIEW ddl_pract.view_one
AS
SELECT T1.id_one, T1.some_text AS first_text, T2.id_two, T2.some_text AS second_text
FROM ddl_pract.table_one T1
INNER JOIN table_two T2 ON T2.id_one = T1.id_one;

SELECT * FROM ddl_pract.view_one;

CREATE VIEW single_view
AS
SELECT 'Hello world!';
------------------------------------------------------------------------------------------------------------------------


-- #9 Материализованные представления
CREATE MATERIALIZED VIEW ddl_pract.mat_view_one
TABLESPACE ext_tabspace
AS
SELECT T1.id_one, T1.some_text AS first_text, T2.id_two, T2.some_text AS second_text
FROM ddl_pract.table_one T1
INNER JOIN table_two T2 ON T2.id_one = T1.id_one;

SELECT * FROM ddl_pract.mat_view_one;

INSERT INTO table_two (id_one, some_text) VALUES (2, '2-2'), (2, '2-3');

SELECT * FROM ddl_pract.view_one;
SELECT * FROM ddl_pract.mat_view_one;

REFRESH MATERIALIZED VIEW ddl_pract.mat_view_one;
SELECT * FROM ddl_pract.mat_view_one;
-----------------------------------------------------------------------------------------------------------------------


-- #10 Роли
DROP ROLE bookkeeper;
DROP ROLE john;
CREATE ROLE bookkeeper CREATEDB;
CREATE ROLE john IN ROLE bookkeeper LOGIN PASSWORD 'john';
-----------------------------------------------------------------------------------------------------------------------


-- #11 Последовательности
CREATE SEQUENCE seq001 START 10;

SELECT nextval('seq001'::regclass);
SELECT setval('seq001'::regclass, 999, false);
SELECT setval('seq001'::regclass, 999);
-----------------------------------------------------------------------------------------------------------------------

 
