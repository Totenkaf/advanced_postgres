/*
Q:
Будет ли временная таблица созданная функцией видна за пределами функции

А:
Будет (естественно в той же сессии, в которой была вызвана функция), если при создании таблицы не использовалась опция ON COMMIT DROP
*/

-- функция, создающаа и заполняющая временную таблицу 
CREATE OR REPLACE FUNCTION fill_temp_table(p_int integer, p_str text)
RETURNS void
AS
$$
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS some_table
    (
        some_int    integer,
        some_str    text
    );
--  )  ON COMMIT DROP;

    INSERT INTO some_table (some_int, some_str) VALUES (p_int, p_str);
END
$$ LANGUAGE plpgsql;    -- с "чистым" SQL не получится

-- Вызов функции 
SELECT fill_temp_table (999, '999');

-- Еще одну строку запишем
INSERT INTO some_table (some_int, some_str) VALUES (1, '11111');

--прочитаем
SELECT * FROM some_table;
-- и удалим
DROP TABLE some_table;
