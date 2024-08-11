USE StackOverflow2013
GO

/* Let's play with the Votes table. */

SELECT t.name,
	COL_NAME(s.object_id, sc.column_id) AS ColumnName,
    s.name,
    s.auto_created,
    s.user_created,
    s.no_recompute,
    s.has_filter,
    s.filter_definition,
    s.is_temporary,
    s.is_incremental,
    s.has_persisted_sample,
    s.stats_generation_method,
    s.stats_generation_method_desc,
    s.auto_drop
FROM sys.stats AS s
	JOIN sys.tables AS t ON s.object_id = t.object_id
	JOIN sys.stats_columns AS sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
WHERE t.name = 'Votes'


/* Run this query.

Wait....This may take a while the first time. Just hit Ctrl + L instead. 
*/

SELECT TOP 1000 * 
FROM dbo.Votes AS v
	JOIN dbo.Posts AS p ON v.PostId = p.Id
	JOIN dbo.VoteTypes AS vt ON v.VoteTypeId = vt.Id
	LEFT JOIN dbo.Users AS u ON v.UserId = u.Id
ORDER BY p.CreationDate DESC




/* check again */
SELECT t.name,
	COL_NAME(s.object_id, sc.column_id) AS ColumnName,
    s.name,
    s.auto_created,
    s.user_created,
    s.no_recompute,
    s.has_filter,
    s.filter_definition,
    s.is_temporary,
    s.is_incremental,
    s.has_persisted_sample,
    s.stats_generation_method,
    s.stats_generation_method_desc,
    s.auto_drop
FROM sys.stats AS s
	JOIN sys.tables AS t ON s.object_id = t.object_id
	JOIN sys.stats_columns AS sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
WHERE t.name = 'Votes'



/* 
-- Don't believe me? Run this and then try the above statements again...

DROP STATISTICS dbo.Votes._WA_Sys_00000002_0AD2A005 -- PostId
DROP STATISTICS dbo.Votes._WA_Sys_00000005_0AD2A005 -- VoteTypeId
DROP STATISTICS dbo.Votes._WA_Sys_00000003_0AD2A005 -- UserId
*/


/* look at the stats for UserID */
SELECT *, 
	(rows_sampled * 1.00/rows) * 100 AS SampleRatePct
FROM sys.dm_db_stats_properties(181575685, 4) 



/* Let's create an index on UserID. This may take a bit... */
CREATE NONCLUSTERED INDEX IDX_Votes_UserID ON dbo.Votes (UserId)



/* Let's see what the stats look like now */
SELECT t.name,
	COL_NAME(s.object_id, sc.column_id) AS ColumnName,
    s.name,
    s.auto_created,
    s.user_created,
    s.no_recompute,
    s.has_filter,
    s.filter_definition,
    s.is_temporary,
    s.is_incremental,
    s.has_persisted_sample,
    s.stats_generation_method,
    s.stats_generation_method_desc,
    s.auto_drop
FROM sys.stats AS s
	JOIN sys.tables AS t ON s.object_id = t.object_id
	JOIN sys.stats_columns AS sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
WHERE t.name = 'Votes'



-- Look more closely at the properties
SELECT sp.stats_id,
       name,
       COL_NAME(stat.OBJECT_ID, sc.column_id) AS ColumnName,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.OBJECT_ID = stat.OBJECT_ID
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.OBJECT_ID, stat.stats_id) AS sp
WHERE stat.OBJECT_ID = OBJECT_ID('Votes');


-- check the histograms:
SELECT sp.stats_id,
       stat.NAME,
       COL_NAME(stat.OBJECT_ID, sc.column_id) AS ColumnName,
       sp.step_number,
       sp.range_high_key,
       sp.range_rows,
       sp.equal_rows,
       sp.distinct_range_rows,
       sp.average_range_rows
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.OBJECT_ID = stat.OBJECT_ID
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_histogram(stat.OBJECT_ID, stat.stats_id) AS sp
WHERE stat.OBJECT_ID = OBJECT_ID('Votes')
      AND sp.stats_id IN ( 4, 5 )
ORDER BY sp.step_number,
         stat.NAME;
;



/* Let's do some updates */

UPDATE dbo.Votes
SET UserID = UserId
WHERE UserID IS NOT NULL
AND Id < 10000000;


/* Adding columns to show where auto updates should be triggered the next time the stats are needed */
SELECT sp.stats_id,
       name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter,
	   500 + (0.20 * rows) AS RowsForChange2014,
	   SQRT(1000 * CONVERT(BIGINT, rows)) AS RowsForChange2016
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Votes');


/*
-- calculation for the autostats update: 
SQL 2014 & earlier compatibility: MIN between 500 + (0.20 * <totalrows>)  
SQL 2016 & greater compatibility: SQRT(1,000 * <totalrows>) 
*/

SELECT 'Full Table' AS 'Counts based on:',
	FORMAT(COUNT(1), 'N', 'en-us') AS Total,
	FORMAT(500 + (0.20 * COUNT(1)), 'N', 'en-us') AS [SQL_2014 -],
	FORMAT(SQRT(1000 * CONVERT(BIGINT, COUNT(1))), 'N', 'en-us') AS [SQL_2016 +]	
FROM dbo.Votes


-- run the select with Ctrl + M
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 1000000


/*
Note the Optimization Stats Usage 

For reference: 
Query Hash:0x90990D40DAD76540
Query Plan Hash:0xC473EE659E2464B1
Optimization Level: FULL
*/

-- Then check the stats again
SELECT sp.stats_id,
       name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter,
	   500 + (0.20 * rows) AS [SQL_2014 -],
	   SQRT(1000 * CONVERT(BIGINT, rows)) AS [SQL_2016 +]
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Votes');



-- check the histograms:
SELECT sp.stats_id,
       stat.NAME,
       COL_NAME(stat.OBJECT_ID, sc.column_id) AS ColumnName,
       sp.step_number,
       sp.range_high_key,
       sp.range_rows,
       sp.equal_rows,
       sp.distinct_range_rows,
       sp.average_range_rows
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.OBJECT_ID = stat.OBJECT_ID
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_histogram(stat.OBJECT_ID, stat.stats_id) AS sp
WHERE stat.OBJECT_ID = OBJECT_ID('Votes')
      AND sp.stats_id IN ( 4, 5 )
ORDER BY sp.step_number,
         stat.NAME;
;



-- what happens when the index is dropped ?
DROP INDEX dbo.Votes.IDX_Votes_UserID 



-- Re-run the select. 
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 1000000

/*
Note the Optimization Stats Usage 

For reference: 
Query Hash:
Query Plan Hash:
Optimization Level:
*/

-- check the stats
SELECT sp.stats_id,
       name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Votes');


/*

--Optional Demo:
--Look at the more in-depth plan information in Query Store
--so you can really see the difference

SELECT qsp.plan_id,
       qsp.query_id,
       qsqt.query_sql_text,
       CONVERT(XML, qsp.query_plan),
       qsp.last_execution_time,
       qsq.last_execution_time
FROM sys.query_store_plan AS qsp
    JOIN sys.query_store_query AS qsq
        ON qsq.query_id = qsp.query_id
    JOIN sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
WHERE qsqt.query_sql_text LIKE '%select * from %Votes%'
      AND qsp.last_execution_time > CONVERT(DATE, GETDATE())
	  AND query_sql_text NOT LIKE '%query_store%';


-- confirm plan_ids
SELECT qsp.plan_id,
       qsp.query_id,
       qsqt.query_sql_text,
       CONVERT(XML, qsp.query_plan),
	   qsq.query_hash,
	   qsp.query_plan_hash,
       qsp.last_execution_time,
       qsq.last_execution_time,
       qsp.count_compiles,
       qsq.count_compiles,
       qsrs.last_execution_time AS RuntimeLastExecTime,
       qsrs.count_executions AS RuntimeCountExec
FROM sys.query_store_plan AS qsp
    JOIN sys.query_store_query AS qsq
        ON qsq.query_id = qsp.query_id
    JOIN sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
    JOIN sys.query_store_runtime_stats AS qsrs
        ON qsrs.plan_id = qsp.plan_id
WHERE qsp.plan_id IN ( 8, 10 )
      AND qsp.last_execution_time > CONVERT(DATE, GETDATE());

-- note the plan used. it's the same. the plan in query store shows that it used index as the optimizer
-- one is showing up as compiled / "retrieved as cache" (with stats). 
-- one is autoparameterized.
-- where's the difference in the plan? optimization level

*/

GO
