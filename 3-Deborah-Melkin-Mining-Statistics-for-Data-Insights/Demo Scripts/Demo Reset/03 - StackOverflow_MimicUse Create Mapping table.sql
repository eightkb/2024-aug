USE StackOverflow_MimicUse
GO

-- Create Mapping table for posts from the first half of 2010, id & accepted answer 
-- we'll need to grab the new ids as they're created and use the map for identifying what the accepted answers are.
DROP TABLE IF EXISTS dbo.NewPostMapping 
;

CREATE TABLE dbo.NewPostMapping 
(
	NewPostMappingID INT IDENTITY(1,1) NOT NULL
		CONSTRAINT PK_NewPostMapping PRIMARY KEY CLUSTERED,
	OldPostID	INT NOT NULL,
	OldAcceptedAnswer INT NULL,
	NewPostID	INT NULL,
	NewAcceptedAnswer INT NULL
);

-- just use the first half of 2010 to recreate the posts.
WITH posts_cte AS
(
	SELECT p.ParentId, ID, CreationDate, p.LastActivityDate, LastEditDate, OwnerUserID, PostTypeID, p.AcceptedAnswerId, -- AS ParentAcceptedAnswer, 
		1 AS PostOrder,
		CONVERT(VARCHAR(max), p.ParentId) + '|' + CONVERT(VARCHAR(10),p.Id) AS SortOrder
	FROM StackOverflow2013.dbo.Posts AS p
	WHERE p.ParentId = 0
	AND DATEPART(YEAR, CreationDate) = 2010 --695,144
	AND DATEPART(MONTH, CreationDate) < 7 --302,185

	UNION ALL
	
	SELECT p.ParentId, p.ID, p.CreationDate, p.LastActivityDate, p.LastEditDate, p.OwnerUserID, p.PostTypeID, p.AcceptedAnswerId ,--pc.ParentAcceptedAnswer, 
		pc.PostOrder + 1 AS PostOrder,
		pc.SortOrder + '|' + CONVERT(VARCHAR(10),p.Id) AS SortOrder
	FROM StackOverflow2013.dbo.Posts AS p
		JOIN posts_cte AS pc ON p.ParentId = pc.Id
)
INSERT INTO NewPostMapping (OldPostID, OldAcceptedAnswer)
SELECT cte.ID, AcceptedAnswerID
FROM posts_cte AS cte
ORDER BY cte.CreationDate
;

GO

INSERT INTO demosetup.Posts
(	OldPostID,
	AcceptedAnswerId,
    AnswerCount,
    Body,
    ClosedDate,
    CommentCount,
    CommunityOwnedDate,
    CreationDate,
    FavoriteCount,
    LastActivityDate,
    LastEditDate,
    LastEditorDisplayName,
    LastEditorUserId,
    OwnerUserId,
    ParentId,
    PostTypeId,
    Score,
    Tags,
    Title,
    ViewCount)
SELECT p.ID,
	p.AcceptedAnswerId,
    p.AnswerCount,
    p.Body,
    p.ClosedDate,
    p.CommentCount,
    p.CommunityOwnedDate,
    p.CreationDate,
    p.FavoriteCount,
    p.LastActivityDate,
    p.LastEditDate,
    p.LastEditorDisplayName,
    p.LastEditorUserId,
    p.OwnerUserId,
    p.ParentId,
    p.PostTypeId,
    p.Score,
    p.Tags,
    p.Title,
    p.ViewCount
FROM StackOverflow2013.dbo.Posts AS p
	JOIN dbo.NewPostMapping AS npm ON npm.OldPostID = p.id

	
INSERT INTO demosetup.Comments
	(OldCommentId,
	CreationDate,
	PostId,
	Score,
	Text,
	UserId
	 )
SELECT p.Id,
	p.CreationDate,
    p.PostId,
    p.Score,
    p.Text,
    p.UserId
FROM StackOverflow2013.dbo.Comments AS p
	JOIN dbo.NewPostMapping AS npm ON npm.OldPostID = p.PostId

	
	
INSERT INTO demosetup.Votes
	(OldVoteID,
	PostId,
    UserId,
    BountyAmount,
    VoteTypeId,
    CreationDate)
SELECT p.Id,
	   p.PostId,
       p.UserId,
       p.BountyAmount,
       p.VoteTypeId,
       p.CreationDate
FROM StackOverflow2013.dbo.Votes AS p
	JOIN dbo.NewPostMapping AS npm ON npm.OldPostID = p.PostId


/* Purge the query store data */
ALTER DATABASE StackOverflow_MimicUse SET QUERY_STORE CLEAR;