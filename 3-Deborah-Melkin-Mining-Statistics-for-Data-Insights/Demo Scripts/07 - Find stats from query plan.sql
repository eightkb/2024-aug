USE StackOverflow_MimicUse
GO

/* XML parsing created with help from https://www.sqlskills.com/blogs/jonathan/digging-into-the-sql-plan-cache-finding-missing-indexes/ */

DROP TABLE IF EXISTS #PlanStats

-- now from query store:
;
WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT tab.query_id, 
	tab.QueryPlanXML,
	tab.query_plan, 
	tab.plan_id,
	tab.query_sql_text,
	tab.ExecCount,
	/* grab the sql text from the query plan */
	n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
	(	/* pull all of the statistics used into a single column 
		that we will break out later*/
		SELECT c.value('(@Database)[1]', 'VARCHAR(128)') + '.' 
				+ c.value('(@Schema)[1]', 'VARCHAR(128)') + '.' 
				+ c.value('(@Table)[1]', 'VARCHAR(128)') + '.' 
				+ c.value('(@Statistics)[1]', 'VARCHAR(128)') +  ', '
		FROM n.nodes('//OptimizerStatsUsage') AS t(cg)
			CROSS APPLY cg.nodes('StatisticsInfo') AS r(c)
		WHERE /* filter by the database name */ 
			c.value('(@Database)[1]', 'VARCHAR(128)') = '[StackOverflow_MimicUse]'
		AND /* filter by the specific tables. 
			this will skip the ones that I created for testing */ 
			c.value('(@Table)[1]', 'VARCHAR(128)') 
				IN ('[Badges]', '[Comments]', '[LinkTypes]', 
					'[PostLinks]', '[Posts]', '[PostTypes]', 
					'[Users]', '[Votes]', '[VoteTypes]'
					)
		FOR  XML PATH('')
	) AS StatList
INTO #PlanStats
FROM
	(	/* get the plans from query store. Could also be modified to use the plan cache dmvs */
		SELECT CONVERT(XML, qp.query_plan) AS QueryPlanXML, 
			qp.query_plan, 
			qp.query_id, 
			qp.plan_id,
			qt.query_sql_text,
			SUM(rs.count_executions) AS ExecCount
		FROM sys.query_store_query_text AS qt
			JOIN sys.query_store_query AS q ON q.query_text_id = qt.query_text_id
			JOIN sys.query_store_plan AS qp ON qp.query_id = q.query_id
			JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = qp.plan_id
		WHERE rs.execution_type_desc = 'Regular'
		GROUP BY 
                 qp.query_plan,
                 qp.query_id,
				 qp.plan_id,
                 qt.query_sql_text
	) AS tab
	/* pull from the StmtSimple node inside the QueryPlanXML 
	using the cte namespace values */
	CROSS APPLY QueryPlanXML.nodes('//StmtSimple') AS q(n)
OPTION(RECOMPILE)

-----------------------------------------

SELECT DBName, st.SchemaName, TBlName, StatName,
	COUNT(DISTINCT st.query_id) AS QueryIdCnt,
	COUNT(DISTINCT st.plan_id) AS PlanIDCnt,
	SUM(st.ExecCount) AS TotalExecCounts
FROM (
	SELECT TRIM(Stats.value) AS Stat,
		MAX(CASE WHEN obj.ordinal = 1 THEN obj.value END) AS DBName,
		MAX(CASE WHEN obj.ordinal = 2 THEN obj.value END) AS SchemaName,
		MAX(CASE WHEN obj.ordinal = 3 THEN obj.value END) AS TblName,
		MAX(CASE WHEN obj.ordinal = 4 THEN obj.value END) AS StatName,
		query_id,
		plan_id,
		CONVERT(XML, query_plan) AS query_plan,
		query_sql_text,
		ExecCount,
		sql_text
	FROM #PlanStats
		CROSS APPLY STRING_SPLIT(StatList, ',') AS Stats
		CROSS APPLY STRING_SPLIT(TRIM(stats.value), '.', 1) AS Obj
	WHERE stats.value <> ''
	GROUP BY query_id,
			 plan_id,
			 query_plan,
			 query_sql_text,
			 ExecCount,
			 sql_text,
			 TRIM(Stats.value) 
	) AS st

GROUP BY st.DBName,
         st.SchemaName, 
		 st.TblName,
         st.StatName
ORDER BY SUM(st.ExecCount) DESC
GO


