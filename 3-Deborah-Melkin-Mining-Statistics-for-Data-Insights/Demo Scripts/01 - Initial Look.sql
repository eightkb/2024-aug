USE StackOverflow2013
GO


/************************************************************/

/* Show what we have the stats. Should just be primary keys */
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
    JOIN sys.tables AS t
        ON s.object_id = t.object_id
    JOIN sys.stats_columns AS sc
        ON sc.object_id = s.object_id
           AND sc.stats_id = s.stats_id;



/*******************************************************************/
/*******************************************************************/
/* Stats already exist. Let's start by looking at the Votes table. 

What we'll use to look at statistic metadata:
* DBCC SHOW_STATISTICS 
* sys.dm_db_stats_properties
* sys.dm_db_stats_histogram

------------------------------------
** NOTE: there are other dmvs, 
but we're not going to go into that 
as part of this session **
------------------------------------
*/
/*******************************************************************/
/*******************************************************************/

DBCC SHOW_STATISTICS(N'dbo.Votes', 'PK_Votes_Id')



/* just look at the header information */
SELECT * FROM sys.dm_db_stats_properties(181575685, 1) 
DBCC SHOW_STATISTICS (N'dbo.Votes', 'PK_Votes_Id') WITH STAT_HEADER



/* just look at the histogram */
SELECT * FROM sys.dm_db_stats_histogram(181575685, 1) 
DBCC SHOW_STATISTICS (N'dbo.Votes', 'PK_Votes_Id') WITH HISTOGRAM 



/* just look at the density vector */
DBCC SHOW_STATISTICS (N'dbo.Votes', 'PK_Votes_Id') WITH DENSITY_VECTOR



/* Let's start creating stats */

SELECT TOP (100) * FROM dbo.Badges
SELECT TOP (100) * FROM dbo.comments
SELECT TOP (100) * FROM dbo.LinkTypes
SELECT TOP (100) * FROM dbo.PostLinks
SELECT TOP (100) * FROM dbo.Posts
SELECT TOP (100) * FROM dbo.PostTypes
SELECT TOP (100) * FROM dbo.Users
SELECT TOP (100) * FROM dbo.Votes
SELECT TOP (100) * FROM dbo.VoteTypes


/* check the stats */
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
    JOIN sys.tables AS t
        ON s.object_id = t.object_id
    JOIN sys.stats_columns AS sc
        ON sc.object_id = s.object_id
           AND sc.stats_id = s.stats_id;





/* 
In order for stats to be created or auto-updated, you have to create queries that need them.
So, let's start creating things ...
*/

/* Start with the one that gets information from posts */
SELECT TOP 10
       p.ParentId,
       ID,
       CreationDate,
       p.LastActivityDate,
       LastEditDate,
       OwnerUserID,
       PostTypeID,
       p.AcceptedAnswerId,
       1 AS PostOrder,
       CONVERT(VARCHAR(MAX), p.ParentId) + '|' + CONVERT(VARCHAR(10), p.Id) AS SortOrder
FROM dbo.Posts AS p
WHERE p.ParentId = 0;


/* what about now? */
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
    JOIN sys.tables AS t
        ON s.object_id = t.object_id
    JOIN sys.stats_columns AS sc
        ON sc.object_id = s.object_id
           AND sc.stats_id = s.stats_id;



/* Let's start by looking at the Posts table more. 

Using sys.dm_db_stats_properties along with other metadata objects to 
get the column names along with all of the stats on the table.*/
SELECT sp.stats_id,
       stat.name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       stat.filter_definition,
       sp.last_updated,
       sp.rows,
       sp.rows_sampled,
       sp.steps,
       sp.unfiltered_rows,
       sp.modification_counter
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Posts');


/*
From the properties
--Total rows in table:	17,142,169
--Total rows sampled:	   146,885
-- density - 0.9637317
*/


/* Similar query, but this time for the histogram */
SELECT sp.stats_id,
       stat.name,
       COL_NAME(stat.object_id, sc.column_id) AS ColumnName,
       sp.step_number,
       sp.range_high_key,
       sp.range_rows,
       sp.equal_rows,
       sp.distinct_range_rows,
       sp.average_range_rows
FROM sys.stats AS stat
    JOIN sys.stats_columns AS sc
        ON sc.object_id = stat.object_id
           AND sc.stats_id = stat.stats_id
    CROSS APPLY sys.dm_db_stats_histogram(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('Posts');


/* Look at the Density */
DBCC SHOW_STATISTICS ('dbo.Posts', '_WA_Sys_0000000F_0519C6AF') WITH DENSITY_VECTOR


-- approximately how many records are unique: (Density)
-- results: 143049.994685693
SELECT 1/6.990563E-06

-- percent of unique rows over rows sampled:
SELECT (1/7.007021E-06)/146885



/* Get information from histogram */

SELECT * FROM sys.dm_db_stats_histogram(85575343, 2)

-- TotalRangeAndEqualRows should equal total rows in table
SELECT SUM(range_rows) AS SumRangeRows, 
	SUM(equal_rows) AS SumEqualRows, 
	SUM(range_rows) + SUM(equal_rows) AS TotalRangeAndEqualRows
FROM sys.dm_db_stats_histogram(85575343, 2)



-- distinct range rows + number of steps = total unique rows
SELECT SUM(distinct_range_rows) AS SumRangeRows, 
	COUNT(*) NoOfSteps, 
	SUM(distinct_range_rows) + COUNT(*) AS TotalUniqueValues
FROM sys.dm_db_stats_histogram(85575343, 2)

GO