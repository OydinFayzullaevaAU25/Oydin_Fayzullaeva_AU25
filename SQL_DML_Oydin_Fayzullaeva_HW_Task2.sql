--1. Create table ‘table_to_delete’ and fill it with the following query:
DROP TABLE IF EXISTS public.table_to_delete; 

CREATE TABLE public.table_to_delete AS
SELECT ('veeeeeery_long_string' || x)::text AS col
FROM generate_series(1, (10^7)::int) AS g(x);

--2. Lookup how much space this table consumes with the following query:

SELECT
  n.nspname                         AS table_schema,
  c.relname                         AS table_name,
  pg_size_pretty(pg_total_relation_size(c.oid))                                AS total,
  pg_size_pretty(pg_indexes_size(c.oid))                                       AS index,
  pg_size_pretty( CASE WHEN c.reltoastrelid = 0
                       THEN 0
                       ELSE pg_total_relation_size(c.reltoastrelid)
                  END )                                                        AS toast,
  pg_size_pretty(pg_table_size(c.oid))                                         AS table_bytes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.oid = 'public.table_to_delete'::regclass
  AND c.relkind = 'r';

--it consumes 575MB

--3. Issue the following DELETE operation on ‘table_to_delete’

DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeery_long_string', '')::int % 3 = 0;

--a. it takes 14s to perform delete statement.
--b. in order to find the size after deletion, we will run the size query again. the results show the following: DELETE marks rows as dead → size usually remains unchanged.
--c. 
VACUUM FULL VERBOSE public.table_to_delete;

--d. After commiting the changes, we will run the size query agin inorder to check the size after vacuum full verbose. The results are following: VACUUM FULL rewrites the table → space is reclaimed; locks table while running.So the size is 383MB
--e. In order to recreate the table, we should first delete the existing public.table_to_delete.
DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT ('veeeeeery_long_string' || x)::text AS col
FROM generate_series(1, (10^7)::int) AS g(x);

--4. Issue the following TRUNCATE operation: TRUNCATE table_to_delete
TRUNCATE TABLE public.table_to_delete;   
--a. it takes 1.0s to execcute truncate function
--b. compared to previous function, truncate function is the fastest.
--c. Get size after TRUNCATE
  SELECT
  pg_size_pretty(pg_total_relation_size('public.table_to_delete')) AS total,
  pg_size_pretty(pg_table_size('public.table_to_delete'))          AS table_only,
  pg_size_pretty(pg_indexes_size('public.table_to_delete'))        AS indexes;

--after truncate function the size is 0 bytes

--5. Investigation Results and Conclusions
/* Space consumption of table_to_delete before and after each operation
  Delete - Space before this function is 575 MB, and after stays the same 575MB. Conclusion: Space was not immediately released back to the OS. The rows were only marked as deleted, and the table size stayed almost the same.
  Vacuum full verbose - space before this function is 575MB but after the size is 383MB. Conclusion: After running Vacuum Full, the table was compacted and unused space was reclaimed.
  Truncate - the size before is 575MB, but after it becomes 0MB. Conclusion: The table was completely cleared and storage was released instantly.
  Duration of each operation
  It takes 14s to perform delete function - slower, especially for large tables, because each row deletionis logged individually.
  Vacuum Full VErbose is slower than delete function, because it takes extra time to reclaim the disc space, but necessary after mass deletes.
  Truncate is the fastest function. it takes 1.0s to perform - as it deallocates entire data pages instead of deleting rows.Truncate can not be rolled backonce commited and resets identity columns. For large data  removals Truncate is preferred, on the other hand 
  on selective deletions, delete is more appropriate.*/

