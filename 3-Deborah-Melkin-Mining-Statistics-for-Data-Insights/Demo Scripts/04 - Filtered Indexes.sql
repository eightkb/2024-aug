USE StackOverflow2013
GO

/* 
	Recreate the index as a filtered index
*/
CREATE NONCLUSTERED INDEX IDX_Votes_UserID_NotNull ON dbo.Votes (UserId)
WHERE UserId IS NOT NULL
GO

-- check the properties
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
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.OBJECT_ID = OBJECT_ID('Votes');


/* What happens on updates? */

/* start with the select */

SELECT COUNT(*) 
FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 1000000

/* Update for ids less than 100,000 */
UPDATE dbo.Votes
SET UserID = UserId
WHERE UserID IS NOT NULL
AND Id < 1000000

-- If 0 records are updated, try adding more

-- check the properties
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
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.object_id = OBJECT_ID('Votes');

-- re-run the select 
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 1000000

-- check the properties
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
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.object_id = OBJECT_ID('Votes');




/*
-- calculation for the autostats update: 
--MIN between 500 + (0.20 * <totalrows>)  and SQRT(1,000 * <totalrows>) 
*/

SELECT 'Full Table' AS 'Counts based on:',
	FORMAT(COUNT(1), 'N', 'en-us') AS Total,
	FORMAT(500 + (0.20 * COUNT(1)), 'N', 'en-us') AS [SQL_2014 -],
	FORMAT(SQRT(1000 * CONVERT(BIGINT, COUNT(1))), 'N', 'en-us') AS [SQL_2016 +]	
FROM dbo.Votes

UNION ALL

-- values just for the filter
SELECT 'UserID NOT NULL',
	FORMAT(COUNT(1), 'N', 'en-us') AS Total,
	FORMAT(500 + (0.20 * COUNT(1)), 'N', 'en-us') AS [SQL_2014 -],
	FORMAT(SQRT(1000 * CONVERT(BIGINT, COUNT(1))), 'N', 'en-us') AS [SQL_2016 +]
FROM dbo.Votes
WHERE UserID IS NOT NULL;
GO


/* Which value is going to trigger updates for the index? */	
/* Update for ids less than 1,000,000 */
UPDATE dbo.Votes
SET UserID = UserId
WHERE UserID IS NOT NULL
AND Id < 1000000

-- re-run the select 
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 1000000



-- check the properties, adding autostats update calc
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
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.object_id = OBJECT_ID('Votes');



/* try again, this time id < 5,000,000. Rerun above queries */
UPDATE dbo.Votes
SET UserID = UserId
WHERE UserID IS NOT NULL
AND Id < 5000000



/* try to do something more specific. 
First, get the estimated plan. Check in between
Second, run the statement.
*/
SELECT * FROM dbo.Votes
WHERE UserID = 400
AND UserID IS NOT NULL
-- property check



-- update the nulls values to a non null value
UPDATE dbo.Votes
SET UserID = 0
WHERE UserID IS NULL
AND Id < 10000000


-- check the properties
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
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.object_id = OBJECT_ID('Votes');


-- re-run the original select 
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL
AND Id < 10000000


-- check the properties
SELECT sp.stats_id,
       name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter ,
	   500 + (0.20 * rows) AS [SQL_2014 -],
	   SQRT(1000 * CONVERT(BIGINT, rows)) AS [SQL_2016 +]
FROM sys.stats AS stat   
	JOIN sys.stats_columns AS sc ON sc.object_id = stat.object_id AND sc.stats_id = stat.stats_id
	CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
WHERE stat.object_id = OBJECT_ID('Votes');

-- One more test....
SELECT * FROM dbo.Votes
WHERE UserID IS NOT NULL

-- reset and redo the tests.
UPDATE dbo.Votes
SET UserID = NULL
WHERE UserID = 0
AND Id < 10000000


/*
Moral of the story: filtered indexes don't have their stats always updated the way we need them to:
https://www.sqlskills.com/blogs/kimberly/filtered-indexes-and-filtered-stats-might-become-seriously-out-of-date/
https://sqlperformance.com/2013/04/t-sql-queries/filtered-indexes
https://sqlperformance.com/2013/04/t-sql-queries/optimizer-limitations-with-filtered-indexes

*/
