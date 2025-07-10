## Настройка autovacuum с учетом особеностей производительности

## Цель:
- запустить нагрузочный тест pgbench 
- настроить параметры autovacuum 
- проверить работу autovacuum

### Задание:
Часть I.
Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB
- Установить на него PostgreSQL 17 с дефолтными настройками
```bash
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-17
```
- Создать БД для тестов: выполнить
```bash
pgbench -i postgres
```
- Запустить:
```bash
pgbench -c8 -P 6 -T 60 -U postgres postgres
```
Результаты
```bash
progress: 6.0 s, 505.8 tps, lat 15.744 ms stddev 7.392, 0 failed
progress: 12.0 s, 494.8 tps, lat 16.145 ms stddev 8.102, 0 failed
progress: 18.0 s, 499.0 tps, lat 16.049 ms stddev 8.529, 0 failed
progress: 24.0 s, 499.0 tps, lat 16.031 ms stddev 8.140, 0 failed
progress: 30.0 s, 497.0 tps, lat 16.078 ms stddev 8.199, 0 failed
progress: 36.0 s, 498.8 tps, lat 16.053 ms stddev 8.208, 0 failed
progress: 42.0 s, 498.8 tps, lat 16.035 ms stddev 8.303, 0 failed
progress: 48.0 s, 497.5 tps, lat 16.080 ms stddev 8.227, 0 failed
progress: 54.0 s, 499.3 tps, lat 16.026 ms stddev 8.350, 0 failed
progress: 60.0 s, 492.7 tps, lat 16.068 ms stddev 8.402, 0 failed

latency average = 16.047 ms
latency stddev = 8.254 ms
initial connection time = 19.022 ms
tps = 498.438440 (without initial connection time)
```
- Применить параметры настройки PostgreSQL из прикрепленного к материалам
занятия файла
```bash
max_connections = 40
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 500
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 6553kB
min_wal_size = 4GB
max_wal_size = 16GB 
```
> Для применения параметров требуется перезагрузка базы данных
```bash
sudo systemctl restart postgresql
```

- Протестировать заново
- Что изменилось и почему?

Результаты:
```bash
progress: 6.0 s, 505.5 tps, lat 15.738 ms stddev 8.795, 0 failed
progress: 12.0 s, 499.5 tps, lat 16.017 ms stddev 8.207, 0 failed
progress: 18.0 s, 499.2 tps, lat 16.033 ms stddev 8.625, 0 failed
progress: 24.0 s, 499.7 tps, lat 16.018 ms stddev 8.345, 0 failed
progress: 30.0 s, 498.7 tps, lat 16.035 ms stddev 8.013, 0 failed
progress: 36.0 s, 496.0 tps, lat 16.131 ms stddev 8.593, 0 failed
progress: 42.0 s, 499.7 tps, lat 16.005 ms stddev 8.128, 0 failed
progress: 48.0 s, 499.5 tps, lat 16.023 ms stddev 8.214, 0 failed
progress: 54.0 s, 499.7 tps, lat 16.009 ms stddev 8.120, 0 failed
progress: 60.0 s, 499.2 tps, lat 16.011 ms stddev 8.528, 0 failed

latency average = 16.004 ms
latency stddev = 8.363 ms
initial connection time = 19.157 ms
tps = 499.764126 (without initial connection time)
```
> Вообще, выглядит так, что не изменилось ничего, все в пределах погрешности. 

Для 2CPU /4GB под OLTP нагрузку мне показались странными следующие значения, поменяем их на рекомендации pgconfig.org и проведем нагрузочное заново:
- maintenance_work_mem = 512 -> 205
- wal_buffers = 16MB -> -1 (в таком случае, будет выделено 3% от shared_buffers = 30MB, возьмем 32MB)
- random_page_cost = 4 -> 1.1 (поднялся на сетевых ssd дисках)
- effective_io_concurrency = 2 -> 200 (поднялся на сетевых ssd дисках)
- work_mem = 6553kB (~6MB) -> 36MB
- min_wal_size = 4GB -> 2GB
- max_wal_size = 16GB -> 3GB (16 вообще бессмысленно, диск максимум на 10GB)

После применения также перезагрузим наш postgresql.

Результаты:
```bash
progress: 6.0 s, 505.5 tps, lat 15.750 ms stddev 8.467, 0 failed
progress: 12.0 s, 499.2 tps, lat 16.016 ms stddev 8.685, 0 failed
progress: 18.0 s, 499.3 tps, lat 16.022 ms stddev 8.843, 0 failed
progress: 24.0 s, 499.5 tps, lat 16.011 ms stddev 8.772, 0 failed
progress: 30.0 s, 498.8 tps, lat 16.043 ms stddev 8.640, 0 failed
progress: 36.0 s, 499.0 tps, lat 16.040 ms stddev 8.551, 0 failed
progress: 42.0 s, 496.0 tps, lat 16.119 ms stddev 9.066, 0 failed
progress: 48.0 s, 499.2 tps, lat 16.030 ms stddev 8.492, 0 failed
progress: 54.0 s, 499.7 tps, lat 16.004 ms stddev 8.253, 0 failed
progress: 60.0 s, 499.7 tps, lat 16.014 ms stddev 7.877, 0 failed

latency average = 16.005 ms
latency stddev = 8.570 ms
initial connection time = 20.235 ms
tps = 499.752274 (without initial connection time)
```

> Как будто тоже эффекта нет, все снова в пределах погрешности.

Проверил кэши, все в порядке, берутся из него, а не диска
```postgresql
SELECT datname, blks_hit, blks_read,
CASE
	WHEN blks_read = 0 THEN NULL -- избегаем деления на ноль
	ELSE 100 * (blks_hit::numeric / (blks_read + blks_hit))
END AS hit_to_read_ratio
FROM pg_stat_database WHERE datname = 'postgres';
```

```bash
 datname  | blks_hit | blks_read |    hit_to_read_ratio
----------+----------+-----------+-------------------------
 postgres |  4232284 |      4902 | 99.88431001140851499100
(1 row)
```

RAM под кэши достаточно (free >10% от total), CPU не перегружен (36.1 >~ 20)
```bash
%Cpu(s): 18.1 us, 12.6 sy,  0.0 ni, 36.1 id, 33.2 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   3910.9 total,   1431.1 free,    229.7 used,   2250.1 buff/cache
```

Инфра тоже в порядке
```bash
iostat –xmt
avg = 0.0

tc -s -d qdisc ls dev ens3
backlog 0b 0p
```

> Отключение только fsync разогнало до 3673.109443
> Отключение только autovacuum эффекта не возымело
> Откуда делаю вывод, что возможно упираемся в производительность самого диска, 10ГБ - очень малый размер для сетевых дисков с ceph под капотом

Часть II.
- Создать таблицу с текстовым полем и заполнить сгенерированными данным в размере 1млн строк
```postgresql
-- 1. Создаем таблицу
CREATE TABLE test_table (
    id serial PRIMARY KEY,
    text_field TEXT
);

-- 2. Заполняем таблицу 1 миллионом записей
INSERT INTO test_table (text_field)
SELECT 
    'random string #' || i || ': ' || md5(random()::text)
FROM 
    generate_series(1, 1000000) AS i;
```
- Посмотреть размер файла с таблицей
Сама таблица:
```postgresql
SELECT pg_size_pretty(pg_relation_size('test_table'));
```

```bash
 pg_size_pretty
----------------
 89 MB
(1 row)
```
- 5 раз обновить все строчки и добавить к каждой строчке любой символ
```postgresql
UPDATE test_table
SET text_field = text_field || '*';
```

- Посмотреть количество мертвых строчек в таблице и когда последний раз приходил автовакуум
Dead Tuples
```postgresql
SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum 
FROM pg_stat_user_tables WHERE relname = 'test_table';
```

```bash
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |          0 |      0 | 2025-07-10 20:14:09.573306+00
(1 row)
```
- Подождать некоторое время, проверяя, пришел ли автовакуум
> Ждал до 20:20, автовакуум не пришел
- 5 раз обновить все строчки и добавить к каждой строчке любой символ
```postgresql
UPDATE test_table
SET text_field = text_field || '%';
```

> Теперь поймал! В прошлый раз автовакуум удачно пришел сразу после обновлений

```postgresql
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |    4999469 |    499 | 2025-07-10 20:14:09.573306+00
(1 row)
```

Пришел и почистил!
```bash
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |          0 |      0 | 2025-07-10 20:21:10.988015+00
(1 row)
```

- Посмотреть размер файла с таблицей
```postgresql
 pg_size_pretty
----------------
 578 MB
(1 row)
```
> Разбухла в 9 раз! И после автовакуума не уменьшилась в размерах!

- Отключить Автовакуум на конкретной таблице
```postgresql
ALTER TABLE test_table SET (autovacuum_enabled = off);
```
- 10 раз обновить все строчки и добавить к каждой строчке любой символ
```postgresql
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..10 LOOP
        RAISE NOTICE 'Шаг цикла: %', i;

        -- Обновляем все строки в таблице
        UPDATE test_table SET text_field = text_field || 'iota';
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```
- Посмотреть размер файла с таблицей
```postgresql
 pg_size_pretty
----------------
 1294 MB
(1 row)
```
> Место ожидаемо возросло. А количество мертвых строк 10-кратно превышает количество существующих. При этом мертвые строчки не очищаются, так как автовакуум выключен
```bash
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |   10000000 |    999 | 2025-07-10 20:21:10.988015+00
(1 row)
```

- Объясните полученный результат
> VACUUM очищает пространство от "мёртвых" строк (удалённых или обновлённых записей).
Он не освобождает место на диске , а помечает его как перезаписываемое для новых/обновлённых строк.
То есть, пространство не возвращается ОС, а остаётся в файле таблицы и будет использовано при последующих INSERT / UPDATE.

- Не забудьте включить автовакуум
```postgresql
ALTER TABLE test_table SET (autovacuum_enabled = on);
```
> Как только вернул автовакуум, прошла примерно минута перед запуском вакуума. Заметил, что почему-то увечилось кол-во n_live_tup, хотя кол-во данных не изменилось

```bash
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000815 |          0 |      0 | 2025-07-10 20:32:01.721572+00
(1 row)
```

```postgresql
postgres=# select count(*) from test_table;
  count
---------
 1000000
(1 row)
```

Решил почистить место через vacuum full и посмотреть за ростом места на диске:
```bash
ubuntu@psql-ubuntu-test:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/vda1       9.6G  6.9G  2.7G  72% /
```

```postgresql
VACUUM FULL ANALYSE test_table;
```

```bash
ubuntu@psql-ubuntu-test:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/vda1       9.6G  5.6G  4.0G  59% /
```

```postgresql
postgres=# SELECT pg_size_pretty(pg_relation_size('test_table'));
 pg_size_pretty
----------------
 135 MB
(1 row)
```

> Забавно, размер на блочном устройстве увеличился на 1.3GB, а размер самой БД не уменьшился до прежних значений - в каждую строчку добавились новые символы во время операций UPDATE

Часть *.

Написать анонимную процедуру, в которой в цикле 10 раз обновятся все строчки в искомой таблице.
Не забыть вывести номер шага цикла. (см.выше)
