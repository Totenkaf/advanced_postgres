#  посмотрим виртуальный id транзакции
SELECT txid_current();

CREATE TABLE test(i int);
INSERT INTO test VALUES (10),(20),(30);

select * from test;

SELECT i, xmin,xmax,cmin,cmax,ctid FROM test;

# посмотрим мертвые записи 
SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum 
FROM pg_stat_user_TABLEs WHERE relname = 'test';

update test set i = 100 where i = 10;


CREATE EXTENSION pageinspect;
\dx+
SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid 
FROM heap_page_items(get_raw_page('test',0));

SELECT * FROM heap_page_items(get_raw_page('test',0)) \gx


# попробуем изменить данные и откатить транзакцию и посмотреть

\echo :AUTOCOMMIT
\set AUTOCOMMIT OFF
commit;

insert into test values(50),(60),(70);

select * from test;

rollback;
commit;


# vacuum

vacuum verbose test;
SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid 
FROM heap_page_items(get_raw_page('test',0));

SELECT pg_relation_filepath('test');

vacuum full test;
SELECT pg_relation_filepath('test');

SELECT name, setting, context, short_desc FROM pg_settings WHERE name like 'vacuum%';

# Autovacuum

SELECT name, setting, context, short_desc FROM pg_settings WHERE name like 'autovacuum%';

SELECT * FROM pg_stat_activity WHERE query ~ 'autovacuum' \gx

select c.relname,
current_setting('autovacuum_vacuum_threshold') as av_base_thresh,
current_setting('autovacuum_vacuum_scale_factor') as av_scale_factor,
(current_setting('autovacuum_vacuum_threshold')::int +
(current_setting('autovacuum_vacuum_scale_factor')::float * c.reltuples)) as av_thresh,
s.n_dead_tup
from pg_stat_user_tables s join pg_class c ON s.relname = c.relname
where s.n_dead_tup > (current_setting('autovacuum_vacuum_threshold')::int
+ (current_setting('autovacuum_vacuum_scale_factor')::float * c.reltuples));


CREATE TABLE student(
  id serial,
  fio char(100)
) WITH (autovacuum_enabled = off);


INSERT INTO student(fio) SELECT 'noname' FROM generate_series(1,1000000);

SELECT pg_size_pretty(pg_total_relation_size('student'));

update student set fio = 'name';

ALTER TABLE student SET (autovacuum_enabled = on);


SELECT pg_size_pretty(pg_total_relation_size('student'));
----

vacuum full student;

SELECT pg_size_pretty(pg_total_relation_size('student'));

SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid 
FROM heap_page_items(get_raw_page('student',0));

SELECT pg_relation_filepath('student');

analyze student;

