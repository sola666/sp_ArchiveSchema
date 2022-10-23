# sp_ArchiveSchema
---

23 OCT, 2022

This procedure is intended to make archiving easier on your MSSQL Server, especially during design sessions - as you can easily stash objects
out of the way, without needing to drop them until you're sure they won't be required later on.

The TABLE DDL portion of this function relies on the sp_GetDDL function written by Lowell Izaguirre which can be downloaded below.

DOWNLOAD SP_GETDDL -> http://www.stormrage.com/SQLStuff/sp_GetDDL_Latest.txt

## PARAMETERS
#### [REQUIRED]
@SCHEMA : Your SCHEMA name (string value).

#### [OPTIONAL]
@ARCHIVE_DATA : Enable/Disable archiving table data to the Archived SCHEMA. Example format : Archived.SCHEMA_TableName

Enabled by default, turn off by executing with parameter set to 0 (FALSE).

## EXAMPLE USAGE
DEFAULT ARCHIVING : EXEC dbo.sp_ArchiveSchema 'invoices'

DISABLED DATA ARCHIVING : EXEC dbo.sp_ArchiveSchema 'invoices', 0
