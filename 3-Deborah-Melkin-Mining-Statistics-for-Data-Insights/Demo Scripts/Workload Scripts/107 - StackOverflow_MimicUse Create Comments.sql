USE StackOverflow_MimicUse
GO

SET NOCOUNT ON 

DECLARE @creationdate DATETIME, @PostID INT, @score INT, @text NVARCHAR(700), @userID INT

DECLARE comment_cursor SCROLL CURSOR FOR
SELECT DATEADD(YEAR, 4, c.CreationDate) AS CreationDate,
       npm.NewPostID AS PostId,
       c.Score,
       c.Text,
       c.UserId
FROM demosetup.Comments AS c
	JOIN dbo.NewPostMapping AS npm ON c.PostId = npm.OldPostID
	LEFT JOIN dbo.Users AS u ON u.Id = c.UserId
WHERE npm.NewPostID IS NOT NULL
AND (-- there's a user in the table or the value is null
	u.Id IS NOT NULL OR c.UserID IS NULL
	)
AND NOT EXISTS (
	SELECT * FROM dbo.Comments AS nc
	WHERE nc.Score = c.Score
	AND nc.Text = c.Text
	--AND ISNULL(nc.UserId, 0) = ISNULL(c.UserId, 0)
	AND nc.CreationDate = DATEADD(YEAR, 4, c.CreationDate)
	AND nc.PostId = npm.NewPostID
	)

OPEN comment_cursor

FETCH FIRST FROM comment_cursor INTO @creationdate, @PostID, @score, @text, @userID

DECLARE @timer DATETIME = GETDATE()
SELECT @timer AS 'Timer Start'

WHILE @@FETCH_STATUS = 0
BEGIN

	IF NOT EXISTS (SELECT * FROM dbo.Users WHERE Id = @userID) AND (@userID IS NOT NULL)
	BEGIN

		SELECT 'Random User ' + CONVERT(VARCHAR(10), @userID), @userID
		
		IF NOT EXISTS (SELECT * FROM dbo.Users WHERE DisplayName = 'Random User ' + CONVERT(VARCHAR(10), @userID))
		BEGIN 
			INSERT INTO dbo.Users
			(
				CreationDate,
				DisplayName,
				DownVotes,
				LastAccessDate,
				Reputation,
				UpVotes,
				Views
			)
			SELECT GETDATE(),
				'Random User ' + CONVERT(VARCHAR(10), @userID),
				0,
				GETDATE(),
				50,
				0,
				1
		END

		SELECT @userID = id FROM dbo.Users WHERE DisplayName = 'Random User ' + CONVERT(VARCHAR(10), @userID)
		
	END

	INSERT INTO dbo.Comments
	(
	    CreationDate,
	    PostId,
	    Score,
	    Text,
	    UserId
	)
	VALUES
	(   @creationdate, -- CreationDate - datetime
	    @PostID,         -- PostId - int
	    @score,      -- Score - int
	    @text,       -- Text - nvarchar(700)
	    @userID      -- UserId - int
	    )
		
	-- Update Viewcount for Post
	UPDATE dbo.Posts
	SET ViewCount = ViewCount + 1
	WHERE Id = @PostID
	
	-- wait for 1/4 second
	WAITFOR DELAY '00:00:00.150'
	
	IF DATEDIFF(SECOND, @timer, GETDATE()) > 3600 -- 60 seconds per minute * 60 minutes per hour
	BEGIN
		BREAK 
		SELECT 'Stopping process after 1 hour. Time ended: ' + CONVERT(VARCHAR(40), GETDATE(), 101)
	END
	ELSE 
	BEGIN
		FETCH NEXT FROM comment_cursor INTO @creationdate, @PostID, @score, @text, @userID
	END
END

CLOSE comment_cursor
DEALLOCATE comment_cursor

GO