/*
1. Free Space Map (FSM):
   - Цель: FSM отслеживает свободное место в каждом странице таблицы. Это позволяет PostgreSQL эффективно находить место для новых записей без необходимости полного сканирования таблицы.
   - Структура: FSM представляет собой массив, в котором каждый элемент соответствует странице таблицы. Значение в элементе FSM указывает на количество свободных байтов на странице.
   - Использование: При вставке новых записей PostgreSQL использует информацию из FSM для быстрого определения страницы с достаточным свободным местом.

2. Visibility Map (VM):
   - Цель: VM используется для оптимизации операций чтения данных, позволяя PostgreSQL избегать чтения ненужных данных при выполнении запросов.
   - Структура: VM представляет собой битовую карту, где каждый бит соответствует странице таблицы. Бит устанавливается, если все строки на странице видимы для всех транзакций.
   - Использование: При выполнении запросов PostgreSQL может использовать VM для пропуска чтения страниц, на которых все данные уже видимы, что ускоряет выполнение запросов.

1. checkpoint_timeout: Этот параметр определяет время (в секундах), через которое PostgreSQL должен запускать автоматический фоновый контрольный пункт (checkpoint), чтобы записать все изменения из журнала транзакций на диск. Если в течение этого времени не был выполнен контрольный пункт, PostgreSQL запустит его автоматически для предотвращения слишком долгого времени восстановления после сбоя. Значение по умолчанию для checkpoint_timeout составляет 5 минут.

2. checkpoint_completion_target: Этот параметр определяет, какую часть контрольного пункта нужно завершить до того, как он будет считаться завершенным. Значение checkpoint_completion_target указывает на то, какую часть данных должно быть записано на диск до завершения контрольного пункта. Значение по умолчанию составляет 0.5, что означает, что контрольный пункт завершается, когда половина данных была записана на диск.

Функции pg_wal_current_insert_lsn() и pg_wal_current_lsn() являются функциями в PostgreSQL, которые используются для работы с журналом записи (WAL, Write-Ahead Logging).

1. pg_wal_current_insert_lsn(): Эта функция возвращает текущую "LSN" (Log Sequence Number) — это уникальный идентификатор каждой записи в журнале записи. LSN используется для отслеживания момента, когда данные были записаны на диск. Функция pg_wal_current_insert_lsn() возвращает LSN, на котором происходит текущая операция записи данных в журнал.

2. pg_wal_current_lsn(): Эта функция также возвращает текущую LSN, но она указывает на конец последней записи в журнале записи. Это означает, что pg_wal_current_lsn() показывает LSN последней успешно записанной операции в журнале.

Отличие между ними заключается в том, что pg_wal_current_insert_lsn() указывает на текущую операцию записи данных, в то время как pg_wal_current_lsn() указывает на конец последней успешно записанной операции. Обе функции полезны для мониторинга и отслеживания состояния журнала записи в PostgreSQL.

1. max_wal_size: Этот параметр определяет максимальный размер, который WAL-файлы могут занимать перед тем, как PostgreSQL начнет перезаписывать старые WAL-файлы. Когда размер WAL-файлов достигает max_wal_size, PostgreSQL начинает перезапись старых файлов. Этот параметр помогает контролировать использование дискового пространства.

2. min_wal_size: Этот параметр указывает минимальный размер, который должны занимать WAL-файлы перед тем, как PostgreSQL начнет перезаписывать старые WAL-файлы. Если размер WAL-файлов опускается ниже min_wal_size, PostgreSQL может приостановить запись данных до тех пор, пока WAL-файлы не будут достаточно заполнены.

3. wal_keep_segments: Этот параметр определяет количество целых WAL-сегментов, которые должны быть сохранены перед тем, как они могут быть перезаписаны. Это помогает обеспечить возможность восстановления данных из WAL-файлов для резервного копирования или восстановления после сбоя.

1. **bgwriter_delay:** Этот параметр определяет интервал времени (в миллисекундах), через который bgwriter будет запускаться для проверки и записи "грязных" блоков из кеша shared_buffers на диск. Увеличение значения bgwriter_delay может снизить нагрузку на систему ввода-вывода (I/O), но может также привести к увеличению количества "грязных" блоков в памяти перед записью на диск.

2. **bgwriter_lru_maxpages:** Этот параметр указывает максимальное количество страниц, которые bgwriter может записать за один проход по списку LRU (Least Recently Used). Увеличение этого значения может ускорить процесс записи на диск, но может также увеличить нагрузку на дисковую подсистему.

3. **bgwriter_lru_multiplier:** Этот параметр управляет тем, как bgwriter выбирает страницы для записи на диск из списка LRU. Умножение значения bgwriter_lru_multiplier на bgwriter_lru_maxpages дает количество страниц, которые могут быть выбраны для записи за один проход. Увеличение этого параметра может привести к более активной записи "грязных" блоков на диск.

XACT - буфферы статусов транзакций
*/

-- Создаем сетевую инфраструктуру для VM:
yc vpc network create --name otus-net --description "otus-net" && \
yc vpc subnet create --name otus-subnet --range 192.168.0.0/24 --network-name otus-net --description "otus-subnet" && \
yc compute instance create --name otus-vm --hostname otus-vm --cores 2 --memory 4 --create-boot-disk size=15G,type=network-hdd,image-folder-id=standard-images,image-family=ubuntu-2004-lts --network-interface subnet-name=otus-subnet,nat-ip-version=ipv4 --ssh-key ~/.ssh/yc_key.pub 

vm_ip_address=$(yc compute instance show --name otus-vm | grep -E ' +address' | tail -n 1 | awk '{print $2}') && ssh -o StrictHostKeyChecking=no -i ~/.ssh/yc_key yc-user@$vm_ip_address 

sudo apt update && sudo apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt -y install postgresql-14 

pg_lsclusters

yc compute instance list

sudo nano /etc/postgresql/14/main/postgresql.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

sudo -u postgres psql
alter user postgres password 'postgres';

sudo pg_ctlcluster 14 main restart


-------- shared_buffers --------
show shared_buffers;

-- проверим размер кеша
select setting, unit from pg_settings where name = 'shared_buffers'; 
-- уменьшим количество буферов для наблюдения
alter system set shared_buffers = 200;

-- рестартуем кластер после изменений
sudo pg_ctlcluster 14 main restart


create table test(i int);

-- сгенерируем значения
insert into test select s.id from generate_series(1, 100) as s(id); 
select * from test limit 10;

-- создадим расширение для просмотра кеша
create extension pg_buffercache; 

select * from pg_buffercache;

create view pg_buffercache_v as
select 
	bufferid,
   	(select c.relname from pg_class c where  pg_relation_filenode(c.oid) = b.relfilenode ) relname,
   	case relforknumber
		when 0 then 'main'
     	when 1 then 'fsm'
     	when 2 then 'vm'
   	end relfork,
   	relblocknumber,
   	isdirty,
   	usagecount
from pg_buffercache b
where b.reldatabase in (0, (select oid from pg_database where datname = current_database()))
and b.usagecount is not null;

select * from pg_buffercache_v where relname = 'test';

select * from test limit 10;

update test set i = 2 where i = 1;

-- увидим грязную страницу
select * from pg_buffercache_v where relname = 'test';


-- даст пищу для размышлений над использованием кеша -- usagecount > 3
select 
	c.relname,
  	count(*) blocks,
  	round( 100.0 * 8192 * count(*) / pg_table_size(c.oid) ) "% of rel",
  	round( 100.0 * 8192 * count(*) filter (where b.usagecount > 3) / pg_table_size(c.oid) ) "% hot"
from pg_buffercache b
join pg_class c on pg_relation_filenode(c.oid) = b.relfilenode
where b.reldatabase in (0, (select oid from pg_database where datname = current_database()))
and b.usagecount is not null
group by c.relname, c.oid
order by 2 desc
limit 10;

-- сгенерируем значения с текстовыми полями - чтобы занять больше страниц
create table test_text(t text);
insert into test_text select 'строка '||s.id from generate_series(1,500) as s(id); 
select * from test_text limit 10;
select * from test_text;
select * from pg_buffercache_v where relname='test_text';

-- интересный эффект
vacuum test_text;


-- посмотрим на прогрев кеша
-- рестартуем кластер для очистки буферного кеша
sudo pg_ctlcluster 14 main restart

select * from pg_buffercache_v where relname = 'test_text';
create extension pg_prewarm;
select pg_prewarm('test_text');
select * from pg_buffercache_v where relname = 'test_text';


----------------- WAL -----------------
sudo /usr/lib/postgresql/14/bin/pg_waldump -r list -- менеджеры ресурсов
/*
▎1. Shared Buffers
- Что это?: Shared buffers — это область памяти, используемая для хранения страниц таблиц и индексов, которые часто запрашиваются. Это кэш, который уменьшает количество операций чтения с диска.
- Как используется?: Когда пользователь выполняет запрос, PostgreSQL сначала проверяет, есть ли нужные страницы в shared buffers. Если страницы отсутствуют, они загружаются с диска.

▎2. WAL Buffers
- Что это?: WAL buffers — это область памяти, где временно хранятся записи WAL (Write-Ahead Log) до их записи на диск.
- Как используется?: Когда транзакция вносит изменения, соответствующие записи сначала помещаются в WAL buffers. Это позволяет агрегировать несколько изменений перед записью на диск, что увеличивает производительность.

▎3. Xact Buffers
- Что это?: Xact buffers (или transaction buffers) используются для хранения информации о текущих транзакциях. Это может включать информацию о том, какие изменения были сделаны в рамках транзакции.
- Как используется?: Эти буферы помогают отслеживать изменения и их состояние до момента завершения транзакции.

▎Взаимодействие между буферами
1. Транзакция начинается: Когда транзакция начинается, создается запись в xact buffer.
2. Изменение данных: При внесении изменений данные помещаются в shared buffers.
3. Запись в WAL: Записи изменений помещаются в WAL buffers.
4. Сброс на диск: По мере заполнения WAL buffers записи сбрасываются на диск, используя fsync. Это гарантирует, что изменения могут быть восстановлены в случае сбоя.

▎Формирование LSN (Log Sequence Number)
- Что это?: LSN — это уникальный идентификатор для каждой записи WAL. Он представляет собой последовательный номер, который указывает на позицию записи в лог-файле.
- Как формируется: LSN генерируется автоматически при создании каждой записи WAL и увеличивается с каждой новой записью. Это позволяет отслеживать порядок изменений и обеспечивает возможность восстановления состояния базы данных.

▎LSN и страницы таблиц
- Имеют ли страницы таблиц LSN?: Да, каждая страница таблицы может содержать информацию о последнем LSN, связанном с изменениями, которые были применены к этой странице. Это позволяет PostgreSQL отслеживать, какие изменения были применены и когда, что важно для управления транзакциями и восстановления данных.

▎Заключение
Таким образом, взаимодействие между xact buffers, WAL buffers и shared buffers обеспечивает эффективное управление данными и их согласованность в PostgreSQL. LSN играет ключевую роль в отслеживании изменений и восстановлении базы данных после сбоев.
*/

create extension pageinspect; -- содержит набор функций/представлений, обеспечивающих нам доступ на нижний уровень к страничкам базы данных (superuser!)
select * from pg_ls_waldir() limit 10; -- 000000010000000000000001 -- что лежит в директории pg_wall

begin transaction;
-- текущая позиция lsn
select pg_current_wal_insert_lsn(); -- 0/17A97F0 - 0/17A97F0
-- посмотрим какой у нас wal file
select pg_walfile_name('0/17A97F0'); -- 000000010000000000000001
update test_text set t = '10' where t = 'строка 1';
select pg_current_wal_lsn(); -- 0/17ABBD0
-- после update номер lsn изменился
select lsn from page_header(get_raw_page('test_text', 0)); -- получим заголовок нашей страницы / 0/17ABB98
-- размер журнальных записей между ними (в байтах):
select '0/17ABBD0'::pg_lsn - '0/17ABB98'::pg_lsn as bytes; -- 56
commit transaction; 

sudo /usr/lib/postgresql/14/bin/pg_waldump -p /var/lib/postgresql/14/main/pg_wal -s 0/17ABBD0 -e 0/17ABD90 000000010000000000000001



---- Checkpoint ----
-- посмотрим информацию о кластере
sudo /usr/lib/postgresql/14/bin/pg_controldata /var/lib/postgresql/14/main/

select pg_current_wal_insert_lsn(); -- 0/17B6D48
checkpoint;
select pg_current_wal_insert_lsn(); -- 0/17B6E30

sudo /usr/lib/postgresql/14/bin/pg_waldump -p /var/lib/postgresql/14/main/pg_wal -s 0/17B6D48 -e 0/17B6E30 000000010000000000000001 -- 0/17B6D48

-- Сымитируем сбой:
insert into test_text values('сбой');

-- sudo pg_ctlcluster 14 main stop -m immediate
sudo pkill -9 postgres


sudo /usr/lib/postgresql/14/bin/pg_controldata /var/lib/postgresql/14/main/ -- 0/1802778
-- кластер выключен, но статус in production
-- запускаем кластер и убеждаемся, что данные накатились
sudo pg_ctlcluster 14 main start

select * from test_text order by t asc limit 10;

sudo cat /var/log/postgresql/postgresql-14-main.log


-- Статистика bgwriter
select * from pg_stat_bgwriter;

-- настройка
show fsync;
show wal_sync_method;
show data_checksums;

alter system set data_checksums = on;

sudo pg_ctlcluster 14 main restart

select pg_relation_filepath('test_text');

-- Остановим сервер и поменяем несколько байтов в странице (сотрем из заголовка LSN последней журнальной записи)
sudo pg_ctlcluster 14 main stop
sudo dd if=/dev/zero of=/var/lib/postgresql/14/main/base/13760/16398 oflag=dsync conv=notrunc bs=1 count=8

-- запустим сервер и попробуем сделать выборку из таблицы
sudo pg_ctlcluster 14 main start

select * from test_text limit 100;

nano /var/lib/postgresql/14/main/base/13760/16398

-- Попробуем нагрузочное тестирование в синхронном и асинхронном режиме
sudo -u postgres pgbench -i postgres
sudo -u postgres pgbench -P 1 -T 10 postgres -- tps = 178.593338

show synchronous_commit;
alter system set synchronous_commit = off;

-- sudo pg_ctlcluster 14 main reload
select pg_reload_conf();

sudo -u postgres pgbench -P 1 -T 10 postgres -- tps = 1330.175775
-- на простых старых hdd разница до 30 раз 


-- Удаляем ВМ и сети:
yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net



