USE [master];
GO

IF OBJECT_ID('[dbo].[sp_ArchiveSchema]') IS NOT NULL
	DROP PROCEDURE [dbo].[sp_ArchiveSchema];
GO
/*===================================================================================================================================================
	AUTHOR : https://github.com/sola666
	UPDATE : 23 OCT, 2022

	This procedure is intended to make archiving easier on your MSSQL Server, especially during design sessions - as you can easily stash objects
  	out of the way, without needing to drop them until you're sure they won't be required later on.

  	The TABLE DDL portion of this function relies on the sp_GetDDL function written by Lowell Izaguirre which can be downloaded below.
  	DOWNLOAD SP_GETDDL >>> http://www.stormrage.com/SQLStuff/sp_GetDDL_Latest.txt

  	PARAMETERS:
  	---------------------------
		[REQUIRED]
		@SCHEMA : Your SCHEMA name (string value).

  		[OPTIONAL]
		@ARCHIVE_DATA : Enable/Disable archiving table data to the Archived SCHEMA. Example format : Archived.SCHEMA_TableName
						Enabled by default, turn off by executing with parameter set to 0 (FALSE).
  	EXAMPLE USAGE:
  	---------------------------
  		DEFAULT ARCHIVING : EXEC dbo.sp_ArchiveSchema 'invoices'
  		DISABLED DATA ARCHIVING : EXEC dbo.sp_ArchiveSchema 'invoices', 0
  Run as EXEC dbo.sp_ArchiveSchema 'YOUR_SCHEMA_NAME'

  	Optional Parameter
--  .▄▄ ·          ▄▄▌   ▄▄▄·
--  ▐█ ▀. ▪        ██•  ▐█ ▀█
--  ▄▀▀▀█▄ ▄█▀▄    ██▪  ▄█▀▀█
--  ▐█▄▪▐█▐█▌.▐▌   ▐█▌▐▌▐█ ▪▐▌
--   ▀▀▀▀  ▀█▄▀▪ ▀ .▀▀▀  ▀  ▀
===================================================================================================================================================*/

CREATE PROCEDURE dbo.sp_ArchiveSchema
    @SCHEMA VARCHAR(MAX),
    @ARCHIVE_DATA BIT = 1
AS
BEGIN
	DECLARE @TABLE_NAME		VARCHAR(MAX);
	DECLARE @TABLE_SCHEMA	VARCHAR(MAX);
	DECLARE @DYNAMIC_SQL	VARCHAR(MAX);

    /*===================================================================================================================
    Create Archived SCHEMA and ArchivedObject table if they do not exist.
	NOTE: The secondary IF NOT EXISTS statement may seem arbitrary, but doubles as an error check in the event that
	the ArchivedObject table has been deleted.
	===================================================================================================================*/
	IF NOT EXISTS(SELECT * FROM SYS.SCHEMAS WHERE NAME = 'Archive')
		BEGIN
			EXEC('CREATE SCHEMA [Archive]')
		END;

	IF NOT EXISTS(SELECT * FROM SYS.TABLES T WHERE T.NAME = 'ArchivedObject' AND SCHEMA_NAME(T.schema_id) = 'Archive')
		BEGIN
			CREATE TABLE archive.ArchivedObject
			(
				ID                INT IDENTITY PRIMARY KEY,
				ORIGINAL_SCHEMA   VARCHAR(MAX),
				OBJECT_NAME       VARCHAR(MAX),
				OBJECT_TYPE       VARCHAR(MAX),
				OBJECT_DEFINITION VARCHAR(MAX),
				DATE_CREATED      DATETIME,
				DATE_ARCHIVED     DATETIME
			);
		END

	/*===================================================================================================================
	Initiate cursor and execute sp_GetDDL on each table, insert into Archive.ArchivedObject
	===================================================================================================================*/
	DECLARE CUR CURSOR FOR
		SELECT TABLE_NAME
		  FROM INFORMATION_SCHEMA.TABLES T
		 WHERE T.TABLE_SCHEMA = @SCHEMA;

	OPEN CUR
	FETCH NEXT FROM CUR INTO @TABLE_NAME
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @TABLE_SCHEMA = @SCHEMA + '.' + @TABLE_NAME;

				INSERT INTO archive.ArchivedObject (OBJECT_DEFINITION)
					   EXEC sp_GetDDL @TABLE_SCHEMA;

				UPDATE OD
					   SET 	ORIGINAL_SCHEMA = 	@SCHEMA,
							OBJECT_NAME     = 	@TABLE_NAME,
							OBJECT_TYPE     = 	'TABLE',
							DATE_CREATED 	= 	T.create_date,
							DATE_ARCHIVED   = 	GETDATE()
					  FROM 	archive.ArchivedObject OD
				INNER JOIN 	SYS.TABLES T
						ON 	SCHEMA_NAME(T.schema_id) =	@SCHEMA
					   AND 	T.NAME = @TABLE_NAME
					 WHERE 	OD.OBJECT_NAME	IS	NULL;

				/*===================================================================================================================
				Archive table data if enabled (enabled by default, refer documentation).
				===================================================================================================================*/
				IF @ARCHIVE_DATA = 1
					BEGIN
						SET @DYNAMIC_SQL = 'SELECT * INTO Archived.' + @SCHEMA + '_' + @TABLE_NAME + ' FROM ' + @TABLE_SCHEMA;
						EXEC @DYNAMIC_SQL;
					END

				FETCH NEXT FROM CUR INTO @TABLE_NAME
			END
		CLOSE CUR
	DEALLOCATE CUR
	
	/*===================================================================================================================
	DDL for non-table objects can be viewed with OBJECT_DEFINITION, so no need for cursor. sys.all_objects gives IDs.
	===================================================================================================================*/
	INSERT INTO archive.ArchivedObject
		SELECT 	@schema,
				ao.name,
				ao.type_desc,
				OBJECT_DEFINITION(OBJECT_ID),
				ao.create_date,
				GETDATE()
		 FROM 	sys.all_objects ao
		WHERE 	SCHEMA_NAME(schema_id) = @schema
		  AND 	ao.type_desc <> 'USER_TABLE';
END;
GO
