-- SELECT current_database();
DROP SCHEMA IF EXISTS toast_test;
CREATE SCHEMA toast_test;

SET search_path = toast_test, public;

CREATE TABLE test_toast
(
	id			integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	field_1		integer NOT NULL,
	field_2		char(4) NOT NULL,
	field_3		smallint NOT NULL,
	field_4		bigint NOT NULL,
	field_5		boolean NOT NULL,
	
	some_text	text
);

SELECT  C1.relname, C1.oid, C1.reltoastrelid, NS.nspname || '.' || C2.relname, C2.oid
FROM pg_class C1
LEFT JOIN pg_class C2 ON C2.oid =  C1.reltoastrelid
INNER JOIN pg_namespace NS ON NS.oid = C2.relnamespace
WHERE C1.relname = 'test_toast'

SELECT * FROM pg_toast.pg_toast_17234;

INSERT INTO test_toast (field_1, field_2, field_3, field_4, field_5, some_text)
SELECT 1, '1224', 2, 3, FALSE, lpad(generate_series (1, 20000)::text, 8, '0');
/*
EXPLAIN ANALYZE
UPDATE test_toast
SET some_text = random()::text
-- Execution Time: 798.048 ms
*/
TRUNCATE TABLE test_toast;
ALTER TABLE test_toast ALTER COLUMN some_text SET STORAGE EXTERNAL;

INSERT INTO test_toast (field_1, field_2, field_3, field_4, field_5, some_text)
SELECT 1, '1224', 2, 3, FALSE, (SELECT string_agg(i::text,'.') FROM generate_series(1,10000) AS i)
FROM generate_series (1, 2);

SELECT pg_relation_filepath ('test_toast');
SELECT pg_relation_filepath ('pg_toast.pg_toast_17234');

TRUNCATE TABLE test_toast;
ALTER TABLE test_toast ALTER COLUMN some_text SET STORAGE PLAIN;


INSERT INTO test_toast (field_1, field_2, field_3, field_4, field_5, some_text)
SELECT 1, '1224', 2, 3, FALSE, lpad(generate_series (1, 20000)::text, 8, '0');

INSERT INTO test_toast (field_1, field_2, field_3, field_4, field_5, some_text)
SELECT 1, '1224', 2, 3, FALSE, (SELECT string_agg(i::text,'.') FROM generate_series(1,800) AS i)
FROM generate_series (1, 2);

SELECT length(some_text) FROM test_toast;

row is too big: size 48952, maximum size 8160