## Работа с уровнями изоляции транзакции в PostgreSQL

## Цель:
- научиться работать в Яндекс Облаке;
- научиться управлять уровнем изолции транзации в PostgreSQL и понимать особенность работы уровней read commited и repeatable read;

### Задание:
В первой сессии новую таблицу и наполнить ее данными:
~~~postgresql
create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov');
insert into persons(first_name, second_name) values('petr', 'petrov');
commit;
~~~

Посмотреть текущий уровень изоляции:
~~~postgresql
show transaction isolation level
~~~

Начать новую транзакцию в обеих сессиях с дефолтным (не меняя) уровнем изоляции
- в первой сессии добавить новую запись
~~~postgresql
begin;
insert into persons(first_name, second_name) values('sergey', 'sergeev');
~~~
- сделать select from persons во второй сессии
~~~postgresql
begin;
select from persons;
~~~
Вопрос: Видите ли вы новую запись и если да то почему?
> Ответ:

завершить первую транзакцию:
~~~postgresql
commit;
~~~
- сделать select from persons во второй сессии
~~~postgresql
begin;
select from persons;
~~~
Вопрос: Видите ли вы новую запись и если да то почему?
> Ответ:

- завершить транзакцию во второй сессии:
~~~postgresql
commit;
~~~

Начать новые, но уже repeatable read транзакции:
~~~postgresql
set transaction isolation level repeatable read;
~~~

- в первой сессии добавить новую запись:
~~~postgresql
begin;
insert into persons(first_name, second_name) values('sveta', 'svetova');
~~~

сделать select * from persons во второй сессии:
~~~postgresql
begin;
select * from persons;
~~~
Вопрос: Видите ли вы новую запись и если да то почему?
> Ответ:

- завершить первую транзакцию:
~~~postgresql
commit;
~~~
- сделать select from persons во второй сессии:
~~~postgresql
select from persons;
~~~

Вопрос: Видите ли вы новую запись и если да то почему?
> Ответ:


- завершить вторую транзакцию
~~~postgresql
commit;
~~~

- сделать select * from persons во второй сессии
~~~postgresql
select * from persons;
~~~

Вопрос: Видите ли вы новую запись и если да то почему?
> Ответ: