/* Load Default Data from Stack Overflow 2013 db */

USE [StackOverflow_MimicUse]
GO

/* LinkTypes */
SET IDENTITY_INSERT dbo.LinkTypes ON 

INSERT INTO dbo.LinkTypes (Id, [Type])
SELECT Id, [Type] FROM StackOverflow2013.dbo.LinkTypes

SET IDENTITY_INSERT dbo.LinkTypes OFF

/* PostTypes */
SET IDENTITY_INSERT dbo.PostTypes ON 

INSERT INTO dbo.PostTypes (Id, [Type])
SELECT Id, [Type] FROM StackOverflow2013.dbo.PostTypes

SET IDENTITY_INSERT dbo.PostTypes OFF


/* VoteTypes */
SET IDENTITY_INSERT dbo.VoteTypes ON 

INSERT INTO dbo.VoteTypes (Id, [Name])
SELECT Id, [Name] FROM StackOverflow2013.dbo.VoteTypes

SET IDENTITY_INSERT dbo.VoteTypes OFF

/* Users */ 
SET IDENTITY_INSERT dbo.Users ON 

INSERT INTO dbo.Users (Id,
       AboutMe,
       Age,
       CreationDate,
       DisplayName,
       DownVotes,
       EmailHash,
       LastAccessDate,
       Location,
       Reputation,
       UpVotes,
       Views,
       WebsiteUrl,
       AccountId
	)
SELECT Id,
       AboutMe,
       Age,
       CreationDate = DATEADD(yy, 4, CreationDate),
       DisplayName,
       DownVotes,
       EmailHash,
       LastAccessDate = DATEADD(yy, 4, LastAccessDate),
       Location,
       Reputation,
       UpVotes,
       Views,
       WebsiteUrl,
       AccountId
FROM StackOverflow2013.dbo.Users

SET IDENTITY_INSERT dbo.Users OFF
GO

/* Badges */
SET IDENTITY_INSERT dbo.Badges ON

INSERT INTO dbo.Badges
(	Id,
    Name,
    UserId,
    Date
)
SELECT b.Id,
       b.Name,
       b.UserId,
       DATEADD(yy, 4, b.Date) 
FROM StackOverflow2013.dbo.Badges AS b
	JOIN dbo.Users ON Users.Id = b.UserId

SET IDENTITY_INSERT dbo.Badges OFF
GO