## Триггеры, поддержка заполнения витрин

## Цель:
- научиться создавать триггер и триггерную функцию для работы с витриной данных

### Задание:
Создать триггер для поддержки витрины в актуальном состоянии.
В БД создана структура, описывающая товары (таблица goods) и продажи (таблица sales).
Есть запрос для генерации отчета – сумма продаж по каждому товару.
БД была денормализована, создана таблица (витрина), структура которой повторяет структуру отчета.

Создать триггер на таблице продаж, для поддержки данных в витрине в актуальном состоянии (вычисляющий при каждой продаже сумму и записывающий её в витрину)
Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

Задание со звездочкой*
Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
Подсказка: В реальной жизни возможны изменения цен.


1. Инициализация
```postgresql
DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE SCHEMA pract_functions;

SET search_path = pract_functions, public;

-- товары:
CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);

INSERT INTO goods (goods_id, good_name, good_price)
VALUES 	(1, 'Спички хозайственные', .50),
		(2, 'Автомобиль Ferrari FXX K', 185000000.01);

-- Продажи
CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);

-- отчет:
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 rows)

-- с увеличением объёма данных отчет стал создаваться медленно
-- Принято решение денормализовать БД, создать таблицу
CREATE TABLE good_sum_mart
(
	good_name   varchar(63) PRIMARY KEY,
	sum_sale	numeric(16, 2) NOT NULL
);

-- Создать триггер (на таблице sales) для поддержки.
-- Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE
```

2. Заполним витрину данными:
```postgresql
INSERT INTO good_sum_mart (good_name, sum_sale)
SELECT 
    G.good_name,
    SUM(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
```

3. Создадим триггерную функцию
```postgresql
CREATE OR REPLACE FUNCTION update_good_sum_mart()
RETURNS TRIGGER AS $$
DECLARE
    good_name_var VARCHAR(63);
    price_var NUMERIC(12, 2);
    delta NUMERIC(16, 2);
BEGIN
    -- Определяем товар и его цену
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT good_name, good_price
        INTO good_name_var, price_var
        FROM goods
        WHERE goods_id = NEW.good_id;

        IF TG_OP = 'INSERT' THEN
            delta := price_var * NEW.sales_qty;
            INSERT INTO good_sum_mart (good_name, sum_sale)
            VALUES (good_name_var, delta)
            ON CONFLICT (good_name)
            DO UPDATE SET sum_sale = good_sum_mart.sum_sale + EXCLUDED.sum_sale;
        END IF;

        IF TG_OP = 'UPDATE' THEN
            delta := price_var * (NEW.sales_qty - OLD.sales_qty);
            INSERT INTO good_sum_mart (good_name, sum_sale)
            VALUES (good_name_var, delta)
            ON CONFLICT (good_name)
            DO UPDATE SET sum_sale = good_sum_mart.sum_sale + EXCLUDED.sum_sale;
        END IF;
    END IF;

    -- При DELETE: вычитаем стоимость
    IF TG_OP = 'DELETE' THEN
        SELECT good_name, good_price
        INTO good_name_var, price_var
        FROM goods
        WHERE goods_id = OLD.good_id;

        delta := price_var * OLD.sales_qty;

        INSERT INTO good_sum_mart (good_name, sum_sale)
        VALUES (good_name_var, -delta)
        ON CONFLICT (good_name)
        DO UPDATE SET sum_sale = good_sum_mart.sum_sale + EXCLUDED.sum_sale;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

4. Создадим триггер
```postgresql
CREATE TRIGGER tr_sales_after_changes
-- реагировать будем на каждое изменение (INSERT, UPDATE, DELETE)
AFTER INSERT OR UPDATE OR DELETE ON sales
-- реагировать будем на изменение любой строчки в исходной таблице sales
FOR EACH ROW
EXECUTE FUNCTION update_good_sum_mart();
```

5. Проверим витрину вначале, добавим новый факт продажи и проверим витрину заново
```postgresql
SELECT * FROM good_sum_mart;
triggers=# SELECT * FROM good_sum_mart;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 rows)

INSERT INTO sales (good_id, sales_qty) VALUES (1, 5);

SELECT * FROM good_sum_mart;
triggers=# SELECT * FROM good_sum_mart;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        68.00
(2 rows)

-- удалим последнюю добавленную запись
DELETE FROM sales WHERE sales_id = 5;

-- проверим работу
triggers=# SELECT * FROM good_sum_mart;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 rows)

-- удалим из sales все упоминаняи good_id=2
DELETE FROM sales WHERE good_id = 2;

-- можно добавить обработку нулевых значений и удалять таковые записи в витрине, но принял решение оставить для наглядной статистики
triggers=# SELECT * FROM good_sum_mart;
        good_name         | sum_sale
--------------------------+----------
 Спички хозайственные     |    65.50
 Автомобиль Ferrari FXX K |     0.00
(2 rows)

-- обновим количество покупок у товара с id=3
UPDATE sales SET sales_qty = '150' WHERE sales_id=3;
triggers=# SELECT * FROM good_sum_mart;
        good_name         | sum_sale
--------------------------+----------
 Автомобиль Ferrari FXX K |     0.00
 Спички хозайственные     |    80.50
(2 rows)
```

-- Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
-- Подсказка: В реальной жизни возможны изменения цен.
Витрина + триггер позволяет фиксировать бизнес-метрики на момент операции, обеспечивая историческую точность отчётов, даже если базовые данные (цены) изменятся в будущем.
Однако, цена товара также может измениться, поэтому мы можем добавить и учет изменения цены, добавив запрос в нашу триггерную функцию
```postgresql
SELECT good_price INTO NEW.sale_price
FROM goods WHERE goods_id = NEW.good_id;
```