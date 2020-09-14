--*************************************************************************--
-- Title: Files to OLTP Database
-- Author: Kenton Ho
-- Desc: This file Bulk inserts CSV filed data. The data is then Incrementally loaded into the OLTP DB 
--		 through an ETL process with SQL code
-- Change Log: When,Who,What
-- 2019-08-19,Kenton,Created ETL Script
--**************************************************************************--
USE [master]
GO
If Exists (Select * from Sysdatabases Where Name = 'FinalTempDB')
	Begin 
		ALTER DATABASE [FinalTempDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE [FinalTempDB]
	End
GO

Create Database [FinalTempDB]
Go

USE FinalTempDB
GO

--********************************************************************--
-- CREATE STAGING TABLES, TRUNCATE, AND BULK INSERT CSV FILES PROCEDURES
--********************************************************************--

--CREATE STAGING TABLES
Create --ALTER
Procedure pETLCreateStagingTable
/* Author: Kenton Ho
** Desc: Create Staging Tables
** Change Log: When,Who,What
** 2019-08-19,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
	SET NOCOUNT ON;
	--Bellevue
	If (Select Object_ID('StagingTableBellevue')) Is NOT null 
		Truncate Table StagingTableBellevue;
	Else 
	CREATE TABLE StagingTableBellevue (
		[Time] Varchar(100) Null,
		[Patient] Varchar(100) Null,
		[Doctor] Varchar(100) Null,
		[Procedure] Varchar(100) Null,
		[Charge] Varchar(100) Null
	)
	--Kirkland
	If (Select Object_ID('StagingTableKirkland')) Is NOT null 
		Truncate Table StagingTableKirkland;
	Else 
	CREATE TABLE StagingTableKirkland (
		[Time] Varchar(100) Null,
		[Patient] Varchar(100) Null,
		[Clinic] Varchar(100) Null,
		[Doctor] Varchar(100) Null,
		[Procedure] Varchar(100) Null,
		[Charge] Varchar(100) Null
	)
	--Redmond
	If (Select Object_ID('StagingTableRedmond')) Is NOT null 
		Truncate Table StagingTableRedmond;
	Else 
	CREATE TABLE StagingTableRedmond (
		[Time] Varchar(100) Null,
		[Clinic] Varchar(100) Null,
		[Patient] Varchar(100) Null,
		[Doctor] Varchar(100) Null,
		[Procedure] Varchar(100) Null,
		[Charge] Varchar(100) Null
	)
	Set NoCount OFF;

   Set @RC = +1
   Print 'Successful'
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
Go

--Test Code
 Declare @Status int;
 Exec @Status = pETLCreateStagingTable;
 Print @Status;
Go

-----------------------------------------------------------------------------------------------
--CSV DATA FILE BULK INSERT
Create Procedure pETLBulkInsert
/* Author: Kenton Ho
** Desc: Bulk Inserts CSV file data
** Change Log: When,Who,What
** 2019-08-19,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
	BULK INSERT StagingTableBellevue
	 FROM 'C:\DataFiles\Bellevue\20100102Visits.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '\n'
		)

	BULK INSERT StagingTableKirkland
	 FROM 'C:\DataFiles\Kirkland\20100102Visits.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '\n'
		)

	BULK INSERT StagingTableRedmond
	 FROM 'C:\DataFiles\Redmond\20100102Visits.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '\n'
		)
   Set @RC = +1
   Print 'Bulk Insert from CSV File was Successfull'
 End Try
  Begin Catch
	Print Error_Message()
	Set @RC = -1
  End Catch
	Return @RC;
 End
GO

--Testing Code:
 Declare @Status int;
 Exec @Status = pETLBulkInsert;
 Print @Status;
GO

--********************************************************************--
-- CREATE VIEW THAT COMBINES ALL STAGING TABLES
--********************************************************************--

--View That combines all the data
CREATE --ALTER 
VIEW vETLNewVisitData
AS (
	SELECT [Time],[Clinic] = 1, [Patient], [Doctor], [Procedure], [Charge] FROM StagingTableBellevue
	UNION
	SELECT [Time], [Clinic], [Patient], [Doctor], [Procedure], [Charge] FROM StagingTableKirkland
	UNION
	SELECT [Time], [Clinic], [Patient], [Doctor], [Procedure], [Charge] FROM StagingTableRedmond
)
GO

SELECT * FROM vETLNewVisitData
GO

--View that transforms the combine data
CREATE VIEW vETLTransformedNewVisitData
AS (
	SELECT
		[Date] = CAST([Time] as datetime),
		[Clinic] = CAST([Clinic] as Int) * 100,
		[Patient] = CAST([Patient] as Int),
		[Doctor] = CAST([Doctor] as Int),
		[Procedure] = CAST([Procedure] as Int),
		[Charge] = CAST([Charge] as money)
	FROM vETLNewVisitData
	)
GO

SELECT * FROM vETLTransformedNewVisitData
GO

--********************************************************************--
-- ETL: INCREMENTAL LOAD FROM STAGING TO OLTP VISIT TABLE 
--********************************************************************--

Create Procedure pETLNewStagingVisitsToPatientDBVisits
(@ImportDate date)
/* Author: Kenton Ho
** Desc: Incremental Loads New Data to Patient DB Visits
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

    -- ETL Processing Code --
	With NewVisits 
	As(
		Select [Date] = CAST(@ImportDate as datetime) + [Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge] FROM vETLTransformedNewVisitData
		Except
		Select [Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge] FROM Patients.dbo.Visits
	  )
	  Insert Into Patients.dbo.Visits
	  ([Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge])
	  SELECT
	  [Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge]
	  FROM NewVisits
	  Order By [Date], [Clinic], [Patient], [Doctor], [Procedure], [Charge]
   Set @RC = +1
   Print 'Incremental Load was Successful'
 End Try
  Begin Catch
	Print Error_Message()
	Set @RC = -1
  End Catch
	Return @RC;
 End
GO

--Test Code
DECLARE @Status Int;
EXEC @Status = pETLNewStagingVisitsToPatientDBVisits @ImportDate = '2019/8/20'
Print @Status
GO

SELECT * FROM Patients.dbo.Visits
GO


--DELETE FROM Patients.dbo.Visits WHERE CAST([Date] as date) = CAST('2019/8/20' as date)