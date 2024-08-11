USE StackOverflow_MimicUse
GO

SET NOCOUNT ON 

DECLARE @PostID INT, @userID INT, @bountyAmount INT, @votetypeid INT, @creationdate DATETIME

DECLARE vote_cursor SCROLL CURSOR FOR 
SELECT npm.NewPostID AS PostId,
       v.UserId,
       v.BountyAmount,
       v.VoteTypeId,
       DATEADD(YEAR, 4, v.CreationDate) AS CreationDate
FROM demosetup.Votes AS v
	JOIN dbo.NewPostMapping AS npm ON npm.OldPostID = v.PostId
	LEFT JOIN dbo.Users AS u ON u.Id = v.UserId
WHERE npm.NewPostID IS NOT NULL
AND (-- there's a user in the table or the value is null
	u.Id IS NOT NULL OR v.UserID IS NULL
	)
AND NOT EXISTS
	(
	SELECT * FROM dbo.Votes AS nv
	WHERE nv.UserId = v.UserId
	AND nv.BountyAmount = v.BountyAmount
	AND nv.VoteTypeId = v.VoteTypeId
	AND nv.CreationDate = DATEADD(YEAR, 4, v.CreationDate)
	AND nv.PostId = npm.NewPostID
	)

OPEN vote_cursor

FETCH FIRST FROM vote_cursor INTO @PostID, @userID, @bountyAmount, @votetypeid, @creationdate

DECLARE @timer DATETIME = GETDATE()
SELECT @timer AS 'Timer Start'

WHILE @@FETCH_STATUS = 0
BEGIN

	INSERT INTO dbo.Votes
	(
	    PostId,
	    UserId,
	    BountyAmount,
	    VoteTypeId,
	    CreationDate
	)
	VALUES
	(   @PostId,
	    @UserId,
	    @BountyAmount,
	    @VoteTypeId,
	    @CreationDate
	    )
		
	-- Update Viewcount for Post
	UPDATE dbo.Posts
	SET ViewCount = ViewCount + 1
	WHERE Id = @PostID

	-- wait for 1/4 second
	WAITFOR DELAY '00:00:00.100'
	
	IF DATEDIFF(SECOND, @timer, GETDATE()) > 3600 -- 60 seconds per minute * 60 minutes per hour
	BEGIN
		BREAK 
		SELECT 'Stopping process after 1 hour. Time ended: ' + CONVERT(VARCHAR(40), GETDATE(), 101)
	END
	ELSE 
	BEGIN
		FETCH NEXT FROM vote_cursor INTO @PostID, @userID, @bountyAmount, @votetypeid, @creationdate
	END
END

CLOSE vote_cursor
DEALLOCATE vote_cursor

SET NOCOUNT OFF

GO 