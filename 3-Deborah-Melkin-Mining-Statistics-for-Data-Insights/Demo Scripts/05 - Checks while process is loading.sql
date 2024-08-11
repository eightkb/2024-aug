USE StackOverflow_MimicUse
GO

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
WHERE sp.modification_counter > 0
AND SCHEMA_NAME(t.schema_id) = 'dbo'
ORDER BY t.name, stat.name