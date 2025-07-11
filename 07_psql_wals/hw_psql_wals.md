## Работа с журналами

## Цель:
- уметь работать с журналами и контрольными точками
- уметь настраивать параметры журналов

### Задание:
Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB
- Установить на него PostgreSQL 17 с дефолтными настройками
```bash
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-17
```
1. Настройте выполнение контрольной точки раз в 30 секунд.
```bash
psql -c "SHOW config_file;"
               config_file
-----------------------------------------
 /etc/postgresql/17/main/postgresql.conf
(1 row)

psql -c "SHOW min_wal_size; SHOW max_wal_size;"
 min_wal_size
--------------
 80MB
(1 row)

 max_wal_size
--------------
 1GB
(1 row)

psql -c 'ALTER SYSTEM SET checkpoint_timeout = "30s";'
psql -c 'ALTER SYSTEM SET log_checkpoints = "on";'

sudo pg_ctlcluster 17 main restart

psql -c 'SHOW checkpoint_timeout;'
 checkpoint_timeout
--------------------
 30s
(1 row)

psql -c 'SHOW log_checkpoints;'
 log_checkpoints
-----------------
 on
(1 row)
```

2. 10 минут c помощью утилиты pgbench подавайте нагрузку.
```bash
# сгенерируем данные в БД postgres
pgbench -i -s 10 postgres
# 10 клиентов в 4 потока на 10 минут, с выводом прогресса раз в 10 сек
pgbench -c 10 -P 10 -j 4 -T 600 -U postgres postgres

duration: 600 s
number of transactions actually processed: 746690
number of failed transactions: 0 (0.000%)
latency average = 8.035 ms
latency stddev = 21.820 ms
initial connection time = 19.119 ms
tps = 1244.334160 (without initial connection time)
```
3. Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку. 
```bash
# точки будем отслеживать через pg_sta

sudo su postgres
# вычислим размер директории с WAL-файлами
du -sh /var/lib/postgresql/17/main/pg_wal/

# до запуска нагрузочного теста после инициализации pgbench
145M	/var/lib/postgresql/17/main/pg_wal/
# количество точек до запуска нагрузочного теста
grep "checkpoint complete" /var/log/postgresql/postgresql-17-main.log | wc -l
6

# после нагрузочного теста
305M	/var/lib/postgresql/17/main/pg_wal/
# количество точек после нагрузочного теста
grep "checkpoint complete" /var/log/postgresql/postgresql-17-main.log | wc -l
25

Итого сгенерировалось 160MB WAL-файлов на 19 чекпоинтов (160 / 19 =~ 8.42MB)
```

4. Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?
```postgresql
# до запуска нагрузочного тестирования
postgres=# select pg_current_wal_insert_lsn();
 pg_current_wal_insert_lsn
---------------------------
 0/9089ED0
(1 row)

# после запуска
 pg_current_wal_insert_lsn
---------------------------
 0/B7C5A860
(1 row)
```
> Вообще, если анализировать ситуацию, за 10 минут при 30 секундном интервале чекпоинтов у меня должно выполнится ровно 20 точек, в моем случае было сделано 19.
5. Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.
```postgresql
psql -c 'ALTER SYSTEM SET synchronous_commit = "off";'
sudo pg_ctlcluster 17 main restart
psql -c 'SHOW synchronous_commit;'
 synchronous_commit
--------------------
 off
(1 row)
```

Для ускорения процедуры, запустим pgbench на 1 минуту
```bash
# 10 клиентов в 4 потока на 10 минут, с выводом прогресса раз в 10 сек
pgbench -c 10 -P 10 -j 4 -T 60 -U postgres postgres

# синхронном случае ранее
tps = 1244.334160 (without initial connection time)

# в асинхронном случае
tps = 4115.342168 (without initial connection time)
```
> PostgreSQL перестал дожидаться подтверждения записи WAL данных на диcк перед тем, как подтверджить выполнение транзакции, тем самым избавились от похода через кэши до диска - сократили время отклика.

6. Создайте новый кластер с включенной контрольной суммой страниц.
```bash
# удалим полностью текущий
sudo pg_dropcluster 17 main --stop
# создадим новый со всеми директориями
sudo pg_createcluster 17 main --start
# остановим
sudo pg_ctlcluster 17 main stop
# удалим main
sudo rm -rf /var/lib/postgresql/17/main

sudo su postgres
# инициализируем заново с --data-checksums
/usr/lib/postgresql/17/bin/initdb -D /var/lib/postgresql/17/main --data-checksums
# не забудем про права
sudo chown -R postgres:postgres /var/lib/postgresql/17/main
# запустим демон обратно
sudo pg_ctlcluster 17 main start

# проверим настройку
psql -c 'show data_checksums;'
 data_checksums
----------------
 on
(1 row)
```
7. Создайте таблицу. Вставьте несколько значений. Найдите расположение файла с таблицей
```postgresql
CREATE TABLE test_checksum(id serial primary key, data text);
INSERT INTO test_checksum(data) VALUES ('test_row_1'), ('test_row_2');

SELECT pg_relation_filepath('test_checksum');
 pg_relation_filepath
----------------------
 base/5/16389
(1 row)
```
8. Выключите кластер.
```bash
sudo pg_ctlcluster 17 main stop
```
9. Измените пару байт в таблице. 
```bash
sudo apt install -y hexedit
hexedit /var/lib/postgresql/17/main/base/5/16389
```
10. Включите кластер и сделайте выборку из таблицы. 
```bash
sudo pg_ctlcluster 17 main start

psql -c 'SELECT * FROM test_checksum;'

WARNING:  page verification failed, calculated checksum 50198 but expected 25908
ERROR:  invalid page in block 0 of relation base/5/16389
```
11. Что и почему произошло? Как проигнорировать ошибку и продолжить работу?
> Произошло то, ради чего была включена проверка - вычисленная контрольная сумма самой страницы не совпадает с той, что указана в ее заголовке, что свидетельствует о потенциальном повреждении данных на диске и требует пристального внимания и/или последующего восстановления таблицы из резервной копии для корректной работы

Проигнорировать:
```bash
psql -c 'ALTER SYSTEM SET ignore_checksum_failure = "on";'
sudo pg_ctlcluster 17 main restart
psql -c 'SHOW ignore_checksum_failure;'
 ignore_checksum_failure
-------------------------
 on
(1 row)

psql -c 'SELECT * FROM test_checksum;'
postgres@psql-ubuntu-test:~/17/main/base/5$ psql -c 'SELECT * FROM test_checksum;'
WARNING:  page verification failed, calculated checksum 50198 but expected 25908
 id |    data
----+------------
  1 | test_row_1
  2 | test_row_2
  3 | test_row_1
  4 | test_row_2
(4 rows)
```
