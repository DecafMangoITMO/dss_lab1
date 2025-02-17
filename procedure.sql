BEGIN;

DO
$$
    BEGIN
        IF NOT has_schema_privilege(current_schema(), 'CREATE') THEN
            RAISE EXCEPTION 'You don''t have permission CREATE for current database';
        END IF;

        RAISE NOTICE 'You have enough permissions';
    END;
$$;

CREATE OR REPLACE PROCEDURE lab_1(full_path text) AS
$$
DECLARE
    schema_name    TEXT;
    table_name     TEXT;
    row            RECORD;
    constraint_row RECORD;
    row_counter    INT := 1;
BEGIN
    IF position('.' IN full_path) > 0 THEN
        schema_name := split_part(full_path, '.', 1);
        table_name := split_part(full_path, '.', 2);
    ELSE
        schema_name := current_schema();
        table_name := full_path;
    END IF;

    -- Check that relation exists
    IF EXISTS(SELECT tablename
              FROM pg_tables
              WHERE schemaname = schema_name
                AND tablename = table_name)
    THEN
        RAISE NOTICE E'\rТаблица: %', full_path;
        RAISE NOTICE E'\r%', repeat(' ', 7);
    ELSE
        RAISE NOTICE E'\rТаблица ''%'' не найдена', full_path;
        RETURN;
    END IF;

    -- Print headers and underline
    RAISE NOTICE E'\rNo. Имя столбца       Атрибуты';
    RAISE NOTICE E'\r% % %',
        repeat('-', 3),
        repeat('-', 17),
        repeat('-', 54);

    FOR row IN (SELECT DISTINCT a.attname,
                       a.attnum,
                       t.typname,
                       a.atttypmod,
                       a.attnotnull,
                       d.description
                FROM pg_attribute AS a
                         JOIN pg_type AS t ON a.atttypid = t.oid -- join to learn a name of each type
                         LEFT JOIN pg_description AS d ON (d.objoid = full_path::regclass AND d.objsubid = a.attnum)
                         LEFT JOIN pg_constraint AS c
                                   ON (c.conrelid = full_path::regclass AND a.attnum = ANY (c.conkey))
                WHERE a.attrelid = full_path::regclass
                  AND a.attnum > 0 -- attributes made by user have positive numbers
    )
        LOOP
            RAISE NOTICE E'\r% % Type: % %',
                rpad(row_counter::text, 4),
                rpad(row.attname, 17),
                CASE WHEN row.atttypmod != -1 THEN row.typname || '(' || (row.atttypmod) || ')' ELSE row.typname END,
                CASE WHEN row.attnotnull THEN 'Not null' ELSE '' END;

            IF row.description IS NOT NULL
            THEN
                RAISE NOTICE E'\r% COMMEN: %',
                    repeat(' ', 22),
                    row.description;
            END IF;

            FOR constraint_row IN
                (SELECT oid, conname, contype
                 FROM pg_constraint AS c
                 WHERE c.conrelid = full_path::regclass
                   AND row.attnum = ANY (c.conkey))
                LOOP
                    RAISE NOTICE E'\r% Constraint: % %',
                        repeat(' ', 22),
                        constraint_row.conname,
                        CASE constraint_row.contype
                            WHEN 'c' THEN pg_get_constraintdef(constraint_row.oid)
                            WHEN 'f' THEN 'Foreign key'
                            WHEN 'p' THEN 'Primary key'
                            WHEN 'u' THEN 'Unique'
                            WHEN 't' THEN 'Trigger'
                            WHEN 'x' THEN 'Exclusion'
                            END;
                END LOOP;

            row_counter := row_counter + 1;
        END LOOP;

END;
$$ LANGUAGE plpgsql;

\prompt 'Введите название таблицы: ' name
CALL lab_1(:'name');

COMMIT;
