USE StackOverflow_MimicUse
GO

DECLARE @loop TINYINT = 0,
    @StartingRowNumber smallint = 1,
    @EndingRowNumber smallint = 50,
	@timer datetime = GETDATE()
	
SELECT @timer AS 'Timer Start'

WHILE DATEDIFF(SECOND, @timer, GETDATE()) < 3600 -- 60 seconds per minute * 60 minutes per hour
BEGIN 

	WITH posts_cte AS
	(
		SELECT p.ParentId, ID, CreationDate, p.LastActivityDate, LastEditDate, OwnerUserID, PostTypeID, p.AcceptedAnswerId AS ParentAcceptedAnswer, 
			p.ViewCount, p.Body,
			1 AS PostOrder,
			CONVERT(VARCHAR(max),p.Id) AS SortOrder
		FROM dbo.Posts AS p
		WHERE p.ParentId IS NULL

		UNION ALL
	
		SELECT p.ParentId, p.ID, p.CreationDate, p.LastActivityDate, p.LastEditDate, p.OwnerUserID, p.PostTypeID, pc.ParentAcceptedAnswer, 
			p.ViewCount, p.Body,
			pc.PostOrder + 1 AS PostOrder,
			pc.SortOrder + '|' + CONVERT(VARCHAR(MAX),p.Id) AS SortOrder
		FROM dbo.Posts AS p
			JOIN posts_cte AS pc ON p.ParentId = pc.Id
	)
	SELECT 
		SUBSTRING(cte.SortOrder, 1, CASE WHEN PATINDEX('%|%', cte.SortOrder) = 0 THEN 100 ELSE PATINDEX('%|%', cte.SortOrder) - 1 END) AS TopID, 
		MIN(c.CreationDate) AS CreationDate,
		MAX(cte.LastActivityDate) AS LastThreadActivityDate,
		MAX(CASE WHEN cte.SortOrder = CONVERT(VARCHAR(max), cte.Id) THEN cte.PostTypeID ELSE NULL END) AS ParentPostTypeID,
		SUM(cte.ViewCount) AS TotalThreadViewCount,
		COUNT(v.Id) AS TotalVotes,
		SUM(v.BountyAmount) AS TotalVoteBountyAmount,
		AVG(v.BountyAmount) AS AvgVoteBountyAmount,
		COUNT(c.Id) AS TotalComments,
		AVG(c.Score) AS AvgCommentScore,
		MAX(CASE WHEN cte.ParentAcceptedAnswer IS NOT NULL THEN 1 ELSE 0 END) AS HasAcceptedAnswer
	FROM posts_cte AS cte
		LEFT JOIN dbo.Votes AS v ON v.PostId = cte.Id
		LEFT JOIN dbo.Comments AS c ON c.PostId = cte.Id
	GROUP BY SUBSTRING(cte.SortOrder, 1, CASE WHEN PATINDEX('%|%', cte.SortOrder) = 0 THEN 100 ELSE PATINDEX('%|%', cte.SortOrder) - 1 END) 
	ORDER BY --SUBSTRING(cte.SortOrder, 1, CASE WHEN PATINDEX('%|%', cte.SortOrder) = 0 THEN 100 ELSE PATINDEX('%|%', cte.SortOrder) - 1 END) 
		COUNT(c.Id) DESC
	OFFSET @StartingRowNumber ROWS
	FETCH NEXT @EndingRowNumber ROWS ONLY


	SELECT @loop = @loop + 1,
		@StartingRowNumber = @StartingRowNumber + @EndingRowNumber

	WAITFOR DELAY '00:00:00.250'
	
END
GO 

SELECT 'Stopping process after 1 hour. Time ended: ' + CONVERT(VARCHAR(40), GETDATE(), 101)