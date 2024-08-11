USE StackOverflow_MimicUse
GO

/* 
I care about data insights. 

Let's write some queries that help me with this.

Completeness: How complete is the data on my tables? Are there are a lot of null values or empty strings? 
Uniqueness: How unique is my data?
Key fields: What fields\statistics are involved the most with my queries? 
	-- This is in a different query window. Start it now since it takes a bit.


*/

/* First, make sure all stats are updated */

EXEC sp_updatestats

/* Umm, is that right? */


SELECT --sp.stats_id,
    t.name AS TableName,
    stat.name AS StatName,
	COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
    filter_definition,
    last_updated,
    rows,
    rows_sampled,
    steps,
    unfiltered_rows,
    modification_counter,
	--500 + (0.20 * rows) AS [SQL_2014 -],
	SQRT(1000 * CONVERT(BIGINT, rows)) AS [SQL_2016 +],
	CASE WHEN modification_counter > SQRT(1000 * CONVERT(BIGINT, rows))
		THEN 'Yes'
		ELSE ''
	END AS 'Ready For Update'
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
	JOIN sys.tables AS t ON sc.object_id = t.object_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE SCHEMA_NAME(t.schema_id) = 'dbo'
ORDER BY t.name, stat.name

/* rebuild all indexes... ?

Using Ola's scripts
*/

EXECUTE DBA.dbo.IndexOptimize
	@Databases = 'StackOverflow_MimicUse',
	@FragmentationLow = 'INDEX_REBUILD_ONLINE',
	@FragmentationMedium = 'INDEX_REBUILD_ONLINE',
	@FragmentationHigh = 'INDEX_REBUILD_ONLINE',
	@FragmentationLevel1 = 5,
	@FragmentationLevel2 = 30,
	@UpdateStatistics = 'ALL',
	@OnlyModifiedStatistics = 'Y'


/*
Completeness of Data:
*/

SELECT sp.stats_id,
	OBJECT_SCHEMA_NAME(stat.object_id) AS SchemaName,
	OBJECT_NAME(stat.object_id) AS TableName,
    COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
    stat.name AS StatName,
	t.name AS DataType,
    sp.last_updated,
    sp.steps,
    sp.rows,
    sp.rows_sampled,
    sp.unfiltered_rows,
	c.is_nullable,
	MAX(CASE WHEN sh.range_high_key IS NULL THEN 1 ELSE 0 END) AS HasNulls, 
	MAX(CASE WHEN sh.range_high_key IS NULL THEN ISNULL(sh.equal_rows, sp.rows) ELSE 0 END) AS NoOfNulls,
	MAX(CASE WHEN sh.range_high_key IS NULL THEN ISNULL(sh.equal_rows, sp.rows) ELSE 0 END * 1.0)/sp.Rows AS PctNull,
	MAX(CASE WHEN sh.range_high_key = 0 THEN 1 ELSE 0 END) AS HasZeros, 
	MAX(CASE WHEN sh.range_high_key = 0 THEN sh.equal_rows ELSE 0 END) AS NoOfZeros,
	MAX(CASE WHEN sh.range_high_key = 0 THEN sh.equal_rows ELSE 0 END * 1.0)/sp.Rows AS PctZero,
	MAX(CASE WHEN sh.range_high_key = '' THEN 1 ELSE 0 END) AS HasEmptyString, 
	MAX(CASE WHEN sh.range_high_key = '' THEN sh.equal_rows ELSE 0 END) AS NoOfEmptyString,
	MAX(CASE WHEN sh.range_high_key = '' THEN sh.equal_rows ELSE 0 END * 1.0)/sp.Rows AS PctEmptyString
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
	JOIN sys.columns AS c  
        ON sc.object_id = c.object_id
           AND sc.column_id = c.column_id
	JOIN sys.types AS t ON c.system_type_id = t.system_type_id AND c.user_type_id = t.user_type_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
    OUTER APPLY sys.dm_db_stats_histogram(stat.object_id, stat.stats_id) AS sh
WHERE OBJECT_SCHEMA_NAME(stat.object_id) = 'dbo'
AND  sc.stats_column_id = 1
GROUP BY OBJECT_SCHEMA_NAME(stat.object_id),
         OBJECT_NAME(stat.object_id),
         COL_NAME(stat.object_id, sc.column_id),
         sp.stats_id,
         stat.name,
         c.is_nullable,
         t.name,
         c.max_length,
         sp.last_updated,
         sp.rows,
         sp.rows_sampled,
         sp.steps,
         sp.unfiltered_rows,
         sp.modification_counter,
         sp.persisted_sample_percent
ORDER BY SchemaName, TableName, StatName, ColumnName


/* Do any of my date have invalid date or dummy dates */

SELECT 
	OBJECT_SCHEMA_NAME(stat.object_id) AS SchemaName,
	OBJECT_NAME(stat.object_id) AS TableName,
    COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
    stat.name AS StatName,
	t.name AS DataType,
    sp.last_updated,
    sp.steps,
    sp.rows,
    sp.rows_sampled,
    sp.unfiltered_rows,
	c.is_nullable,
	CASE WHEN MAX(CASE WHEN sh.step_number = 1 THEN sh.range_high_key ELSE NULL END) IS NOT NULL
		THEN MAX(CASE WHEN sh.step_number = 1 THEN sh.range_high_key ELSE NULL END)
		ELSE MAX(CASE WHEN sh.step_number = 2 THEN sh.range_high_key ELSE NULL END)
	END AS MinHighRangeKey,
	CASE WHEN MAX(CASE WHEN sh.step_number = 1 THEN sh.range_high_key ELSE NULL END) IS NOT NULL
		THEN MAX(CASE WHEN sh.step_number = 1 THEN sh.distinct_range_rows ELSE NULL END)
		ELSE MAX(CASE WHEN sh.step_number = 2 THEN sh.distinct_range_rows ELSE NULL END)
	END AS DistinctValuesBelowMinHighRange,
	MAX(sh.range_high_key) AS MaxHighRangeKey
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
	JOIN sys.columns AS c  
        ON sc.object_id = c.object_id
           AND sc.column_id = c.column_id
	JOIN sys.types AS t ON c.system_type_id = t.system_type_id AND c.user_type_id = t.user_type_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
    CROSS APPLY sys.dm_db_stats_histogram(stat.object_id, stat.stats_id) AS sh
WHERE OBJECT_SCHEMA_NAME(stat.object_id) = 'dbo'
AND  sc.stats_column_id = 1
AND t.name LIKE 'date%'
GROUP BY OBJECT_SCHEMA_NAME(stat.object_id),
         OBJECT_NAME(stat.object_id),
         COL_NAME(stat.object_id, sc.column_id),
		stat.name,
		t.name,
		sp.last_updated,
		sp.steps,
		sp.rows,
		sp.rows_sampled,
		sp.unfiltered_rows,
		c.is_nullable
ORDER BY SchemaName, TableName, ColumnName, StatName



/*
Uniqueness:
*/

-- How many unique values in the key tables? density is not in sys.dm_db_stats_properties 
DECLARE @tblname NVARCHAR(512), @statname NVARCHAR(128), @sql NVARCHAR(MAX)

DROP TABLE IF EXISTS #densityvector
CREATE TABLE #densityvector
(
	DensityVectorID INT IDENTITY(1,1) PRIMARY KEY,
	TableName	NVARCHAR(512),
	StatName	NVARCHAR(128),
	AllDensity	FLOAT,
	AverageLength	FLOAT,
	Columns		NVARCHAR(MAX)
)

DECLARE stat_cursor SCROLL CURSOR FOR
SELECT OBJECT_SCHEMA_NAME(stat.object_id) + '.' + OBJECT_NAME(stat.object_id) AS TableName, 
	stat.name
FROM sys.stats AS stat
WHERE OBJECT_SCHEMA_NAME(stat.object_id) = 'dbo'
ORDER BY stat.object_id, stat.stats_id

OPEN stat_cursor

FETCH FIRST FROM stat_cursor INTO @tblname, @statname

WHILE @@FETCH_STATUS = 0
BEGIN

	SELECT @sql = 'DBCC SHOW_STATISTICS (N''' + @tblname + ''', N''' + @statname + ''') WITH DENSITY_VECTOR'

	INSERT INTO #densityvector
	(
	    AllDensity,
	    AverageLength,
	    Columns
	)
	EXEC sp_executesql @sql

	UPDATE #densityvector
	SET TableName = @tblname, 
		StatName=  @statname
	WHERE TableName IS NULL
	
	FETCH NEXT FROM stat_cursor INTO @tblname, @statname

END

CLOSE stat_cursor
DEALLOCATE stat_cursor

--SELECT * FROM #densityvector

/* create the fuller query with the info I need */
SELECT TableName,
       StatName,
       Columns,
       --AllDensity,
	   sp.last_updated,
       sp.rows,
       sp.unfiltered_rows,
       sp.rows_sampled,
	   1/AllDensity AS ApproxUniqueRows,
	   (1.0/AllDensity)/sp.rows AS PctUnique,
       AverageLength ,
       sp.steps
FROM #densityvector AS dv
	JOIN sys.stats AS s ON s.object_id = OBJECT_ID(dv.TableName) AND s.name = dv.StatName
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
ORDER BY TableName, StatName, dv.Columns



/* as an aside, could the average length for a single column indicate 
whether a string data type column is sized properly? */
SELECT dv.DensityVectorID,
       dv.TableName,
       dv.StatName,
       dv.Columns, 
       dv.AllDensity,
       dv.AverageLength,
	   SUM(c.max_length) SumOfColumnMaxLength
FROM sys.columns AS c
	JOIN #densityvector AS dv ON c.object_id = OBJECT_ID(dv.TableName)
		AND dv.Columns LIKE '%' + c.name + '%'
GROUP BY dv.DensityVectorID,
         dv.TableName,
         dv.StatName,
         dv.AllDensity,
         dv.AverageLength,
         dv.Columns


/* Distinct values for the columns? */

SELECT 
	OBJECT_SCHEMA_NAME(stat.object_id) AS SchemaName,
	OBJECT_NAME(stat.object_id) AS TableName,
    stat.name AS StatName,
    COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
	t.name AS DataType,
    sp.last_updated,
    sp.steps,
    sp.rows,
    sp.rows_sampled,
    sp.unfiltered_rows,
	c.is_nullable,
	SUM(sh.distinct_range_rows) + sp.steps AS TotalUniqueValues
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
	JOIN sys.columns AS c  
        ON sc.object_id = c.object_id
           AND sc.column_id = c.column_id
	JOIN sys.types AS t ON c.system_type_id = t.system_type_id AND c.user_type_id = t.user_type_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
    CROSS APPLY sys.dm_db_stats_histogram(stat.object_id, stat.stats_id) AS sh
WHERE OBJECT_SCHEMA_NAME(stat.object_id) = 'dbo'
AND  sc.stats_column_id = 1
GROUP BY OBJECT_SCHEMA_NAME(stat.object_id),
         OBJECT_NAME(stat.object_id),
         COL_NAME(stat.object_id, sc.column_id), 
         stat.name,
         t.name,
         sp.last_updated,
         sp.steps,
         sp.rows,
         sp.rows_sampled,
         sp.unfiltered_rows,
         c.is_nullable
ORDER BY SchemaName, TableName, StatName, ColumnName

