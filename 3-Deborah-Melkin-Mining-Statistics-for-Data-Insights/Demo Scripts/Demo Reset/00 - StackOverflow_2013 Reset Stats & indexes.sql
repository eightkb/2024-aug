/* NOTE: This can take from 6 to 20 minutes to run */

USE StackOverflow2013
GO

/* reset stats & indexes. Rebuild existing indexes as well */
-- thanks, Brent!
EXEC [dbo].[DropIndexes]

EXECUTE DBA.dbo.IndexOptimize
	@Databases = 'StackOverflow2013',
	@FragmentationLow = 'INDEX_REBUILD_ONLINE',
	@FragmentationMedium = 'INDEX_REBUILD_ONLINE',
	@FragmentationHigh = 'INDEX_REBUILD_ONLINE',
	@FragmentationLevel1 = 5,
	@FragmentationLevel2 = 30,
	@UpdateStatistics = 'ALL',
	@OnlyModifiedStatistics = 'Y'

	
/* Purge the query store data */
ALTER DATABASE StackOverflow2013 SET QUERY_STORE CLEAR;
GO