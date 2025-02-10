CREATE OR REPLACE PROCEDURE lab_1(table_name text) AS $$
    DECLARE
        row RECORD;
        row_counter INT := 1;
    BEGIN
        -- Check that relation exists
        IF EXISTS(
            SELECT tablename
            FROM pg_tables
            WHERE tablename = table_name
        )
        THEN
            RAISE NOTICE 'Таблица: %', table_name;
            RAISE NOTICE ' ';
        ELSE
            RAISE NOTICE 'Таблица ''%'' не найдена', table_name;
            RETURN;
        END IF;

        -- Print headers and underline
        RAISE NOTICE 'No. Имя столбца       Атрибуты';
        RAISE NOTICE ' % % %',
            repeat('-', 3),
            repeat('-', 17),
            repeat('-', 54)
        ;

        FOR row IN (
            SELECT
                a.attname,
                t.typname,
                a.attnotnull,
                d.description,
                c.contype
            FROM pg_attribute AS a
                     JOIN pg_type AS t ON a.atttypid = t.oid -- join to learn a name of each type
                     LEFT JOIN pg_description AS d ON (d.objoid = table_name::regclass AND d.objsubid = a.attnum)
                     LEFT JOIN pg_constraint AS c ON (c.conrelid = table_name::regclass AND a.attnum = ANY(c.conkey))
            WHERE a.attrelid = table_name::regclass
            AND a.attnum > 0 -- attributes made by user have positive numbers
        )
        LOOP
            RAISE NOTICE '% % Type: % %',
                rpad(row_counter::text, 4),
                rpad(row.attname, 17),
                row.typname,
                 CASE WHEN row.attnotnull THEN 'Not null' ELSE '' END;

            IF row.description IS NOT NULL
            THEN
                RAISE NOTICE '% COMMEN: %',
                    repeat(' ', 22),
                    row.description;
            END IF;

            IF row.contype IS NOT NULL THEN
                RAISE NOTICE '% Constraint: %',
                    repeat(' ', 22),
                    CASE row.contype
                        WHEN 'c' THEN 'Check'
                        WHEN 'f' THEN 'Foreign key'
                        WHEN 'p' THEN 'Primary key'
                        WHEN 'u' THEN 'Unique'
                        WHEN 't' THEN 'Trigger'
                        WHEN 'x' THEN 'Exclusion'
                        END;
            END IF;

            row_counter := row_counter + 1;
        END LOOP;

    END;
$$ LANGUAGE plpgsql;
