USE StackOverflow2013
GO

/*
Now we're going to start how statistics show data profiling information....

Let's look at the Users tables
*/

/*
Start by adding a non clustered index.
*/

CREATE NONCLUSTERED INDEX IDX_User_DisplayName ON dbo.Users (DisplayName)

/* Now let's look at the statistics */

DBCC SHOW_STATISTICS (N'dbo.Users', 'PK_Users_Id') 
DBCC SHOW_STATISTICS (N'dbo.Users', 'IDX_User_DisplayName')


/* For fun\future reference: 
	All density = 4.055622E-07
	total rows: 2465713  
	density for DisplayName index alone: 0.7902294
*/

/* From Density Vector */
SELECT 1/5.306348E-07 AS UniqueDisplayName
SELECT 1/4.055622E-07 AS UniqueDisplayNameandID
SELECT (1/5.306348E-07) / 2465713 AS Pct

-- Uniqueness of names, checking from the table directly:
SELECT COUNT(DISTINCT DisplayName) AS #DistinctNames, 
	COUNT(*) AS TotalUsers,
	(COUNT(DISTINCT DisplayName) * 1.0)/ COUNT(*) AS PercentDistinctNames
FROM dbo.Users	






/* Let's add an index with multiple columns, name as the second column */

CREATE NONCLUSTERED INDEX IDX_User_EmailDisplayName ON dbo.Users (EmailHash, DisplayName)



DBCC SHOW_STATISTICS (N'dbo.Users', 'IDX_User_EmailDisplayName') 




/* Are you saying what I think you're saying??? */



SELECT * FROM dbo.Users
WHERE EmailHash IS NOT NULL



/* let's do a different index instead, where there's a mix */


CREATE NONCLUSTERED INDEX IDX_User_LocationDisplayName ON dbo.Users ([Location], DisplayName)



DBCC SHOW_STATISTICS (N'dbo.Users', 'IDX_User_LocationDisplayName') 

/* 
Density Vector:
Location = 2.228114E-05
Location & Display = 4.906641E-07
*/

-- confirm the number of rows being returned. Run with the properties

SELECT * FROM sys.dm_db_stats_properties(149575571, 4)

SELECT SUM(range_rows) AS SumRangeRows, 
	SUM(equal_rows) AS SumEqualRows, 
	SUM(range_rows) + SUM(equal_rows) AS TotalRangeEqualRows
FROM sys.dm_db_stats_histogram(149575571, 4)



/* How does the statistics track with the actual data? */

SELECT * FROM sys.dm_db_stats_histogram(149575571, 4)
WHERE step_number BETWEEN 20 AND 30



/* so what number is reflected in that equal_row value? */

SELECT [Location], DisplayName, 
	COUNT(*) AS UniqueLocationDisplayCount, 
	SUM(1) OVER(PARTITION BY Location) TotalRowsReturned
FROM dbo.Users AS u
WHERE u.Location = 'Boston, MA'
GROUP BY u.Location,
         u.DisplayName


-- rows returned: 2090


-- just location
SELECT [Location], COUNT(*)
FROM dbo.Users AS u
WHERE u.Location = 'Boston, MA'
GROUP BY u.Location


-- count = 2178


/* Do the actual data numbers and stat histogram line up? */
SELECT Test.Location, Test.LocationCnt,
	SUM(Test.LocationCnt)
		OVER (
			ORDER BY Location
			ROWS UNBOUNDED PRECEDING
			) AS RunningTotal,
	SUM(Test.LocationCnt * 1.0)
		OVER (
			ORDER BY Location
			ROWS UNBOUNDED PRECEDING
			) / ROW_NUMBER() OVER(ORDER BY Location) AS AvgUniqueRows
FROM (
	SELECT [Location], COUNT(*) LocationCnt
	FROM dbo.Users AS u
	WHERE u.Location > 'Bogota, Colombia'
	AND u.Location <= 'Boston, MA'
	GROUP BY u.Location
	) AS Test
ORDER BY test.Location


SELECT * FROM sys.dm_db_stats_histogram(149575571, 4)
WHERE range_high_key = 'Boston, MA'


/*

DBCC SHOW_STATISTICS (N'dbo.Users', 'IDX_User_LocationDisplayName') WITH DENSITY_VECTOR


Total Density for index: 0.1739246
Density for Columns: 4.906641E-07
	(1/density for key columns = 2038054.13927777)
EQ_Rows: 2178


-- 
Remember: RANGE_ROWS/DISTINCT_RANGE_ROWS = AVG_RANGE_ROWS

SELECT SUM(range_rows) AS SumRangeRows, 
	SUM(equal_rows) AS SumEqualRows, 
	SUM(range_rows) + SUM(equal_rows) AS TotalRangeEqualRows -- Total rows sampled
FROM sys.dm_db_stats_histogram(149575571, 4)
WHERE range_high_key = 'Boston, MA'

density vector - 1/distinct values


*/



/* what happens if you have multi column index and no stats on the other columns? 

Let's use the comments table

*/

CREATE INDEX IDX_Comment_CreationDatePostId ON dbo.Comments (CreationDate, PostId)
GO


-- This may take a bit. Run Ctrl + L
SELECT c.PostId,
       MIN(CreationDate) AS FirstCommentDate,
       MAX(CreationDate) AS LastCommentDate
FROM dbo.Comments AS c
GROUP BY c.PostId;




SELECT sp.stats_id,
       name,
       STRING_AGG(COL_NAME(stat.object_id, sc.column_id), ', ') AS ColumnNames,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter,
	   SQRT(1000 * CONVERT(BIGINT, rows)) AS [SQL_2016 +]
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Comments')
GROUP BY sp.stats_id,
         stat.name,
         stat.filter_definition,
         sp.last_updated,
         sp.rows,
         sp.rows_sampled,
         sp.steps,
         sp.unfiltered_rows,
         sp.modification_counter
;


/* how are stats affected by updates? */
UPDATE c
SET PostID = PostID
FROM dbo.Comments AS c
WHERE PostId < 1000


SELECT sp.stats_id,
       name,
       STRING_AGG(COL_NAME(stat.object_id, sc.column_id), ', ') AS ColumnNames,
       filter_definition,
       last_updated,
       rows,
       rows_sampled,
       steps,
       unfiltered_rows,
       modification_counter,
	   SQRT(1000 * CONVERT(BIGINT, rows)) AS [SQL_2016 +]
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Comments')
GROUP BY sp.stats_id,
         stat.name,
         stat.filter_definition,
         sp.last_updated,
         sp.rows,
         sp.rows_sampled,
         sp.steps,
         sp.unfiltered_rows,
         sp.modification_counter
;

/* confirm which stats are being used through the execution plan. */
SELECT c.PostId,
       MIN(CreationDate) AS FirstCommentDate,
       MAX(CreationDate) AS LastCommentDate
FROM dbo.Comments AS c
GROUP BY c.PostId;
GO