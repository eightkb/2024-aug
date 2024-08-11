USE StackOverflow_MimicUse
GO

/*
Posts will be added in one at a time because that's closer to how it would be through the app since we wouldn't be doing things one by one
*/


/*
-- create a temp table for the 
	* new id, 
	* new CreationDate for the new LastActivityDate

*/
DROP TABLE IF EXISTS #Updates

CREATE TABLE #Updates
(
	OldPostID	INT,
	NewPostID	INT,
	ActivityDate	DATETIME
)

/*
steps for adding in posts, done in a loop
- add post with modified values
*/

SET NOCOUNT ON

-- initial insert. we'll update later
DECLARE @mappingid INT,
	@body NVARCHAR(MAX),
	@communityowneddate DATETIME,
	@creationdate DATETIME,
	@lastactivitydate DATETIME,
	@ownerUserID INT,
	@parentid INT,
	@posttypeid INT,
	@score INT,
	@tags NVARCHAR(150),
	@title NVARCHAR(250),
	@NewAAPostID INT, 
	@ParentNewPostID INT

/* turn into a cursor so all the values being inserted into the table are variables, as if from code */
DECLARE post_cursor SCROLL CURSOR FOR 
SELECT np.NewPostMappingID AS MappingId, 
	   --op.Id,
       --NULL AS AcceptedAnswerId,
       --0 AS AnswerCount,
       op.Body,
       -- NULL ClosedDate,
       --0 AS CommentCount,
       DATEADD(YEAR, 4, op.CommunityOwnedDate) AS CommunityOwnedDate, 
       DATEADD(YEAR, 4, op.CreationDate) AS CreationDate,
       --0 AS FavoriteCount,
       DATEADD(YEAR, 4, op.CreationDate) AS LastActivityDate,
       --NULL AS LastEditDate,
       --NULL AS LastEditorDisplayName,
       --NULL AS LastEditorUserId,
       op.OwnerUserId,
       CASE WHEN op.ParentID = 0 
		THEN NULL 
		ELSE op.ParentID
	   END	AS ParentId,
       op.PostTypeId,
       op.Score,
       op.Tags,
       op.Title/*,
       0 AS ViewCount */
FROM demosetup.Posts AS op
	JOIN dbo.NewPostMapping AS np ON op.OldPostId = np.OldPostID
	LEFT JOIN dbo.NewPostMapping AS aa ON op.ParentId = aa.OldPostID
WHERE np.NewPostID IS NULL

OPEN post_cursor

FETCH FIRST FROM post_cursor INTO 
	@mappingid, @body, @communityowneddate, @creationdate, @lastactivitydate, 
	@ownerUserID, @parentid, @posttypeid, @score, @tags, @title

/* Automatically stop running after 1 hour */

DECLARE @timer DATETIME = GETDATE()
SELECT @timer AS 'Timer Start'

WHILE @@FETCH_STATUS = 0
BEGIN 

	IF NOT EXISTS (SELECT * FROM dbo.Users WHERE Id = @ownerUserID) AND (@ownerUserID IS NOT NULL)
	BEGIN

		--SELECT 'Random User ' + CONVERT(VARCHAR(10), @ownerUserID), @ownerUserID
		
		IF NOT EXISTS (SELECT * FROM dbo.Users WHERE DisplayName = 'Random User ' + CONVERT(VARCHAR(10), @ownerUserID))
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
				'Random User ' + CONVERT(VARCHAR(10), @ownerUserID),
				0,
				GETDATE(),
				50,
				0,
				1
		END

		SELECT @ownerUserID = id FROM dbo.Users WHERE DisplayName = 'Random User ' + CONVERT(VARCHAR(10), @ownerUserID)
		
	END

	SELECT @ParentNewPostID = np.NewPostID
	FROM dbo.NewPostMapping AS np
	WHERE np.OldPostID = @parentid

	INSERT INTO dbo.Posts
	(
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
		ViewCount
	)
	OUTPUT @mappingid, inserted.id, inserted.CreationDate 
	INTO #Updates (OldPostID, NewPostID, ActivityDate)
	SELECT --op.Id,
		   NULL AS AcceptedAnswerId,
		   0 AS AnswerCount,
		   @body AS Body,
		   NULL ClosedDate,
		   0 AS CommentCount,
		   @communityowneddate AS CommunityOwnedDate, 
		   @creationdate AS CreationDate,
		   0 AS FavoriteCount,
		   @lastactivitydate AS LastActivityDate,
		   NULL AS LastEditDate,
		   NULL AS LastEditorDisplayName,
		   NULL AS LastEditorUserId,
		   @ownerUserID AS OwnerUserId,
		   @ParentNewPostID AS ParentId,
		   @posttypeid AS PostTypeId,
		   @score AS Score,
		   @tags AS Tags,
		   @title AS Title,
		   0 AS ViewCount 	

	/* update mapping table */
	--SELECT *
	UPDATE np SET np.NewPostID = u.NewPostID
	FROM #Updates AS u
		JOIN dbo.NewPostMapping AS np ON np.NewPostMappingID = u.OldPostID
	WHERE np.NewPostMappingID = @mappingid

	/*
	-- If the post has a parent id, update the parent post 
		* with ViewCount + 1, 
		* LastActivityDate to the new ActivityDate
	*/

	
	IF EXISTS (
		SELECT *
		FROM dbo.NewPostMapping AS p
			JOIN dbo.NewPostMapping AS aa ON aa.OldAcceptedAnswer = p.OldPostID
		WHERE p.NewPostMappingID = @mappingid
		)
	BEGIN

		-- get the new post id for the accepted answer
		SELECT @NewAAPostID = NewPostID
		FROM dbo.NewPostMapping AS p
		WHERE p.NewPostMappingID = @mappingid
		
		--SELECT @ParentNewPostID, @NewAAPostID

		-- update the mapping table
		UPDATE p
		SET p.NewAcceptedAnswer = @NewAAPostID
		FROM dbo.NewPostMapping AS p 
		WHERE NewPostID = @ParentNewPostID

		/* Update the Posts table */
		UPDATE p
		SET AcceptedAnswerID = @NewAAPostID,
			p.ViewCount = p.ViewCount + 1,
			p.LastActivityDate = @LastActivityDate
		FROM dbo.Posts AS p
		WHERE Id = @ParentNewPostID

	END
	ELSE
	BEGIN

		IF @ParentNewPostID IS NOT NULL
			UPDATE p
			SET p.ViewCount = p.ViewCount + 1,
				p.LastActivityDate = @LastActivityDate
			FROM dbo.Posts AS p
			WHERE Id = @ParentNewPostID
	END

	-- reset for the next round
	TRUNCATE TABLE #updates
	SELECT @NewAAPostID = NULL

	IF DATEDIFF(SECOND, @timer, GETDATE()) > 3600 -- 60 seconds per minute * 60 minutes per hour
	BEGIN
		BREAK 
		SELECT 'Stopping process after 1 hour. Time ended: ' + CONVERT(VARCHAR(40), GETDATE(), 101)
	END
	ELSE 
	BEGIN
		FETCH NEXT FROM post_cursor INTO 
			@mappingid, @body, @communityowneddate, @creationdate, @lastactivitydate, 
			@ownerUserID, @parentid, @posttypeid, @score, @tags, @title
	END
END

CLOSE post_cursor
DEALLOCATE post_cursor


SET NOCOUNT OFF 