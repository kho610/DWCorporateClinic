--*************************************************************************--
-- Title: Final- Backup Automations
-- Author: Kenton Ho
-- Desc: This script creates backup sprocs for all 3 databases on the final
-- Change Log: When,Who,What
-- 2019-08-20,Kenton,Created Backups/Restoration Script
--**************************************************************************--

USE [Master]

--********************************************************************--
-- DoctorSchedule Backup
--********************************************************************--

--Create Back up Device

If Exists (SELECT name FROM sys.objects WHERE name = N'pCreateDoctorsSchedulesBackupDevice')
Begin
  Drop Proc pCreateDoctorsSchedulesBackupDevice;
End
go

Create -- Drop
Proc pCreateDoctorsSchedulesBackupDevice
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DoctorsSchedules DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Device Code --
    If NOT Exists (Select * From model.sys.sysdevices Where Name = N'DoctorsSchedulesBackupDevice')
      Exec master.dbo.sp_AdDumpDevice
        @devtype = N'disk'
      , @logicalname = N'DoctorsSchedulesBackupDevice'
      , @physicalname = N'C:\BackupFiles\DoctorsSchedulesBackupDevice.bak'
		-- Backup Device Code --
		Print 'Success in Creating Backing Device for the DoctorsSchedules database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error in Creating Backing Device for the DoctorsSchedules database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec master.dbo.sp_dropdevice @logicalname = N'DoctorsSchedulesBackupDevice'
Exec pCreateDoctorsSchedulesBackupDevice
*/
GO

-----------------------------------------------------------------------------------------------------
--Create Maintance for Backup

If Exists (SELECT name FROM sys.objects WHERE name = N'pMaintBackupDoctorsSchedules')
Begin
  Drop Proc pMaintBackupDoctorsSchedules;
End
go

Create -- Drop
Proc pMaintBackupDoctorsSchedules
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DoctorsSchedules DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Code --
    If (DatePart(dw,GetDate()) = 1)-- Sunday
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Sun-Full', Init;
    Else                                                             
    If (DatePart(dw,GetDate()) = 2)-- Monday                         
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Mon-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 3)-- Tuesday                        
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Tue-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 4)-- Wednesday                      
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Wed-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 5)-- Thursday                       
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Thu-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 6)-- Friday                         
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Fri-Full';  
    Else                                                             
    If (DatePart(dw,GetDate()) = 7)-- Saturday                       
      Backup Database DoctorsSchedules To DoctorsSchedulesBackupDevice With Name = 'Sat-Full';
		-- Backup Code --
		Print 'Success in Backing up the DoctorsSchedules database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Backing up the DoctorsSchedules database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pMaintBackupDoctorsSchedules;
Restore HeaderOnly From DISK = N'C:\BackupFiles\DoctorsSchedulesBackupDevice.bak'
*/
GO

-----------------------------------------------------------------------------------------------
--Refresh DoctorSchedulesDev Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pRefreshDoctorsSchedulesDev')
  Begin
    Drop Proc pRefreshDoctorsSchedulesDev;
  End
go

Create -- Drop
Proc pRefreshDoctorsSchedulesDev
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates/Refreshes a Dev Database based on the Sunday "First File" 
--       backup of the DoctorsSchedules DB. 
--       (If you wanted the latest file each day you need to add logic to find it with Restore_Header)
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Restore Code --
    -- Step 1) Kick everyone off the database as needed 
    If Exists (Select * From Sys.databases where Name = 'DoctorsSchedulesDev')
      Begin
        Alter Database DoctorsSchedulesDev set Single_user with rollback immediate;
      End

    Restore database DoctorsSchedulesDev 
      From Disk = N'C:\BackupFiles\DoctorsSchedulesBackupDevice.bak' 
      With File = 1
          , Move N'DoctorsSchedules' TO N'C:\BackupFiles\DoctorsSchedulesDev.mdf'
          , Move N'DoctorsSchedules_log' TO N'C:\BackupFiles\DoctorsSchedulesDev.ldf'
          , Recovery -- Makes the DB open for use
          , Replace -- Replaces the DB as needed 
		-- Step 3) Change to Multi-User (should not need this, but I have seen it "Stick" to Single_User before) 
    Alter Database DoctorsSchedulesDev set Multi_user with rollback immediate;
    -- Restore Code --
		Print 'Success in Restoring the DoctorsSchedules database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Restoring the DoctorsSchedules database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test
Exec pRefreshDoctorsSchedulesDev
Select * From DoctorsSchedulesDev.Sys.Tables
*/
Go

-----------------------------------------------------------------------------------------------
--Restore Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pTestRestoreFromDoctorsSchedules')
  Begin
    Drop Proc [pTestRestoreFromDoctorsSchedules];
  End
go

Create Proc pTestRestoreFromDoctorsSchedules
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Test that the DoctorsSchedules and the DoctorsSchedulesDev are the same.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created File
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
    -- Setup Code -- 
      If NOT Exists (SELECT name FROM [tempdb].sys.objects WHERE name = N'DoctorsSchedulesMaintLog')
        Begin
          Create Table [tempdb].dbo.DoctorsSchedulesMaintLog
          ( LogID int Primary Key Identity
          , LogEntry nvarchar(2000) 
          , LogEntryDate datetime Default GetDate()
          );
        End
	  -- Validate Restore Code --
      Declare @CurrentCount int, @RestoredCount int;
      -- Test Row Counts
      Select @CurrentCount = count(*) From [DoctorsSchedules].[dbo].[DoctorShifts];
      Select @RestoredCount = count(*) From [DoctorsSchedulesDev].[dbo].[DoctorShifts];
      If (@CurrentCount = @RestoredCount)
        Insert Into [tempdb].dbo.DoctorsSchedulesMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Passed';
      Else
        Insert Into [tempdb].dbo.DoctorsSchedulesMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Failed';
      -- Review Data
      Select Top (5) * From [DoctorsSchedules].[dbo].[DoctorShifts] Order By 1 Desc;
      Select Top (5) * From  [DoctorsSchedulesDev].[dbo].[DoctorShifts] Order By 1 Desc;
		-- Validate Restore Code --
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Testing the DoctorsSchedules database Backup and Restore';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pTestRestoreFromDoctorsSchedules;
SELECT * FROM tempdb.dbo.DoctorsSchedulesMaintLog
*/


--********************************************************************--
-- Patients Backup
--********************************************************************--

--Create Back up Device

If Exists (SELECT name FROM sys.objects WHERE name = N'pCreatePatientsBackupDevice')
Begin
  Drop Proc pCreatePatientsBackupDevice;
End
go

Create -- Drop
Proc pCreatePatientsBackupDevice
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DoctorsSchedules DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Device Code --
    If NOT Exists (Select * From model.sys.sysdevices Where Name = N'PatientsBackupDevice')
      Exec master.dbo.sp_AdDumpDevice
        @devtype = N'disk'
      , @logicalname = N'PatientsBackupDevice'
      , @physicalname = N'C:\BackupFiles\PatientsBackupDevice.bak'
		-- Backup Device Code --
		Print 'Success in Creating Backing Device for the Patients database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error in Creating Backing Device for the Patients database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec master.dbo.sp_dropdevice @logicalname = N'PatientsBackupDevice'
Exec pCreatePatientsBackupDevice
*/
GO

-----------------------------------------------------------------------------------------------------
--Create Maintance for Backup

If Exists (SELECT name FROM sys.objects WHERE name = N'pMaintBackupPatients')
Begin
  Drop Proc pMaintBackupPatients;
End
go

Create -- Drop
Proc pMaintBackupPatients
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DoctorsSchedules DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Code --
    If (DatePart(dw,GetDate()) = 1)-- Sunday
      Backup Database Patients To PatientsBackupDevice With Name = 'Sun-Full', Init;
    Else                                                             
    If (DatePart(dw,GetDate()) = 2)-- Monday                         
       Backup Database Patients To PatientsBackupDevice With Name = 'Mon-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 3)-- Tuesday                        
      Backup Database Patients To PatientsBackupDevice With Name = 'Tue-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 4)-- Wednesday                      
       Backup Database Patients To PatientsBackupDevice With Name = 'Wed-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 5)-- Thursday                       
       Backup Database Patients To PatientsBackupDevice With Name = 'Thu-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 6)-- Friday                         
      Backup Database Patients To PatientsBackupDevice With Name = 'Fri-Full';  
    Else                                                             
    If (DatePart(dw,GetDate()) = 7)-- Saturday                       
       Backup Database Patients To PatientsBackupDevice With Name = 'Sat-Full';
		-- Backup Code --
		Print 'Success in Backing up the Patients database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Backing up the Patients database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pMaintBackupPatients
Restore HeaderOnly From DISK = N'C:\BackupFiles\PatientsBackupDevice.bak'
*/
GO

-----------------------------------------------------------------------------------------------
--Refresh or create DoctorSchedulesDev Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pRefreshPatientsDev')
  Begin
    Drop Proc pRefreshPatientsDev;
  End
go

Create -- Drop
Proc pRefreshPatientsDev
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates/Refreshes a Dev Database based on the Sunday "First File" 
--       backup of the DoctorsSchedules DB. 
--       (If you wanted the latest file each day you need to add logic to find it with Restore_Header)
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Restore Code --
    -- Step 1) Kick everyone off the database as needed 
    If Exists (Select * From Sys.databases where Name = 'PatientsDev')
      Begin
        Alter Database PatientsDev set Single_user with rollback immediate;
      End
    
    Restore database PatientsDev 
      From Disk = N'C:\BackupFiles\PatientsBackupDevice.bak' 
      With File = 1
          , Move N'Patients' TO N'C:\BackupFiles\PatientsDev.mdf'
          , Move N'Patients_log' TO N'C:\BackupFiles\PatientsDev.ldf'
          , Recovery -- Makes the DB open for use
          , Replace -- Replaces the DB as needed 
		-- Step 3) Change to Multi-User (should not need this, but I have seen it "Stick" to Single_User before) 
    Alter Database PatientsDev set Multi_user with rollback immediate;
    -- Restore Code --
		Print 'Success in Restoring the Patients database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Restoring the Patients database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test
Exec pRefreshPatientsDev
Select * From PatientsDev.Sys.Tables
*/
Go

-----------------------------------------------------------------------------------------------
--Restore Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pTestRestoreFromPatients')
  Begin
    Drop Proc [pTestRestoreFromPatients];
  End
go

Create Proc pTestRestoreFromPatients
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Test that the Patients and the PatientsDev are the same.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created File
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
    -- Setup Code -- 
      If NOT Exists (SELECT name FROM [TempDB].sys.objects WHERE name = N'PatientsMaintLog')
        Begin
          Create Table [TempDB].dbo.PatientsMaintLog
          ( LogID int Primary Key Identity
          , LogEntry nvarchar(2000) 
          , LogEntryDate datetime Default GetDate()
          );
        End
	  -- Validate Restore Code --
      Declare @CurrentCount int, @RestoredCount int;
      -- Test Row Counts
      Select @CurrentCount = count(*) From [Patients].[dbo].[Patients];
      Select @RestoredCount = count(*) From [PatientsDev].[dbo].[Patients];
      If (@CurrentCount = @RestoredCount)
        Insert Into [TempDB].dbo.PatientsMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Passed';
      Else
        Insert Into [TempDB].dbo.PatientsMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Failed';
      -- Review Data
      Select Top (5) * From [Patients].[dbo].[Patients] Order By 1 Desc;
      Select Top (5) * From  [PatientsDev].[dbo].[Patients] Order By 1 Desc;
		-- Validate Restore Code --
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Testing the DoctorsSchedules database Backup and Restore';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pTestRestoreFromPatients
SELECT * FROM tempdb.dbo.PatientsMaintLog
*/
GO


--********************************************************************--
-- DWClinicReportData Backup
--********************************************************************--

--Create Back up Device

If Exists (SELECT name FROM sys.objects WHERE name = N'pCreateDWClinicReportDataBackupDevice')
Begin
  Drop Proc pCreateDWClinicReportDataBackupDevice
End
go

Create -- Drop
Proc pCreateDWClinicReportDataBackupDevice
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DWClinicReportData DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Device Code --
    If NOT Exists (Select * From model.sys.sysdevices Where Name = N'DWClinicReportDataBackupDevice')
      Exec master.dbo.sp_AdDumpDevice
        @devtype = N'disk'
      , @logicalname = N'DWClinicReportDataBackupDevice'
      , @physicalname = N'C:\BackupFiles\DWClinicReportDataBackupDevice.bak'
		-- Backup Device Code --
		Print 'Success in Creating Backing Device for the DWClinicReportData database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error in Creating Backing Device for the DWClinicReportData database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec master.dbo.sp_dropdevice @logicalname = N'DWClinicReportDataBackupDevice'
Exec pCreateDWClinicReportDataBackupDevice
*/
GO

-----------------------------------------------------------------------------------------------------
--Create Maintance for Backup

If Exists (SELECT name FROM sys.objects WHERE name = N'pMaintBackupDWClinicReportData')
Begin
  Drop Proc pMaintBackupDWClinicReportData
End
go

Create -- Drop
Proc pMaintBackupDWClinicReportData
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates a backup device for the DWClinicReportData DB as needed.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Backup Code --
    If (DatePart(dw,GetDate()) = 1)-- Sunday
      Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Sun-Full', Init;
    Else                                                             
    If (DatePart(dw,GetDate()) = 2)-- Monday                         
       Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Mon-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 3)-- Tuesday                        
      Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Tue-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 4)-- Wednesday                      
       Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Wed-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 5)-- Thursday                       
       Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Thu-Full';
    Else                                                             
    If (DatePart(dw,GetDate()) = 6)-- Friday                         
      Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Fri-Full';  
    Else                                                             
    If (DatePart(dw,GetDate()) = 7)-- Saturday                       
      Backup Database DWClinicReportData To DWClinicReportDataBackupDevice With Name = 'Sat-Full';
		-- Backup Code --
		Print 'Success in Backing up the DWClinicReportData database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Backing up the DWClinicReportData database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pMaintBackupDWClinicReportData
Restore HeaderOnly From DISK = N'C:\BackupFiles\DWClinicReportDataBackupDevice.bak'
*/
GO

-----------------------------------------------------------------------------------------------
--Refresh or create DWClinicReportData Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pRefreshDWClinicReportDataDev')
  Begin
    Drop Proc pRefreshDWClinicReportDataDev;
  End
go

Create -- Drop
Proc pRefreshDWClinicReportDataDev
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Creates/Refreshes a Dev Database based on the Sunday "First File" 
--       backup of the DWClinicReportData DB. 
--       (If you wanted the latest file each day you need to add logic to find it with Restore_Header)
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created Sproc
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
		-- Restore Code --
    -- Step 1) Kick everyone off the database as needed 
    If Exists (Select * From Sys.databases where Name = 'DWClinicReportDataDev')
      Begin
        Alter Database PatientsDev set Single_user with rollback immediate;
      End
    
    Restore database DWClinicReportDataDev
      From Disk = N'C:\BackupFiles\DWClinicReportDataBackupDevice.bak' 
      With File = 1
          , Move N'DWClinicReportData' TO N'C:\BackupFiles\DWClinicReportDataDev.mdf'
          , Move N'DWClinicReportData_log' TO N'C:\BackupFiles\DWClinicReportDataDev.ldf'
          , Recovery -- Makes the DB open for use
          , Replace -- Replaces the DB as needed 
		-- Step 3) Change to Multi-User (should not need this, but I have seen it "Stick" to Single_User before) 
    Alter Database PatientsDev set Multi_user with rollback immediate;
    -- Restore Code --
		Print 'Success in Restoring the DWClinicReportData database';
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Restoring the DWClinicReportData database';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test
Exec pRefreshDWClinicReportDataDev
Select * From DWClinicReportDataDev.Sys.Tables
*/
Go

-----------------------------------------------------------------------------------------------
--Restore Database

If Exists (SELECT name FROM sys.objects WHERE name = N'pTestRestoreFromDWClinicReportData')
  Begin
    Drop Proc [pTestRestoreFromDWClinicReportData];
  End
go

Create Proc pTestRestoreFromDWClinicReportData
--*************************************************************************--
-- Dev: Kenton Ho
-- Desc: Test that the DWClinicReportDataand the DWClinicReportDataDev are the same.
-- Change Log: When,Who,What
-- 2019-08-20,Kenton Ho,Created File
--**************************************************************************--
As 
Begin
	Declare @RC int = 0;
	Begin Try 
    -- Setup Code -- 
      If NOT Exists (SELECT name FROM [TempDB].sys.objects WHERE name = N'DWClinicReportDataMaintLog')
        Begin
          Create Table [TempDB].dbo.DWClinicReportDataMaintLog
          ( LogID int Primary Key Identity
          , LogEntry nvarchar(2000) 
          , LogEntryDate datetime Default GetDate()
          );
        End
	  -- Validate Restore Code --
      Declare @CurrentCount int, @RestoredCount int;
      -- Test Row Counts
      Select @CurrentCount = count(*) From [DWClinicReportData].[dbo].[DimDates];
      Select @RestoredCount = count(*) From [DWClinicReportDataDev].[dbo].[DimDates];
      If (@CurrentCount = @RestoredCount)
        Insert Into [TempDB].dbo.DWClinicReportDataMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Passed';
      Else
        Insert Into [TempDB].dbo.DWClinicReportDataMaintLog (LogEntry)
         Select [Test] = 'Row Count Test: Failed';
      -- Review Data
      Select Top (5) * From [DWClinicReportData].[dbo].[DimDates] Order By 1 Desc;
      Select Top (5) * From [DWClinicReportDataDev].[dbo].[DimDates] Order By 1 Desc;
		-- Validate Restore Code --
		Set @RC = 1;
  End Try
  Begin Catch 
		Print 'Error Testing the DoctorsSchedules database Backup and Restore';
		Print ERROR_MESSAGE();
		Set @RC = -1;
  End Catch
  Return @RC;
End -- Proc
go

/* Test Code
Exec pTestRestoreFromDWClinicReportData
SELECT * FROM tempdb.dbo.DWClinicReportDataMaintLog
*/
GO

--********************************************************************--
-- EXECUTION CODE 
--********************************************************************--

/* Test Code

--Step 1)
****CREATE FOLDER ON C DRIVE CALLED "BackupFiles" to store these backups


--Step 2)
*****Excute store procedures to test for backup and restore functions for each database

--DoctorSchedules
Exec master.dbo.sp_dropdevice @logicalname = N'DoctorsSchedulesBackupDevice'
Exec pCreateDoctorsSchedulesBackupDevice
Exec pMaintBackupDoctorsSchedules
Exec pRefreshDoctorsSchedulesDev
Exec pTestRestoreFromDoctorsSchedules

Select * From DoctorsSchedulesDev.Sys.Tables;
Select * From TempDB.dbo.DoctorsSchedulesMaintLog;

--Patients 
Exec master.dbo.sp_dropdevice @logicalname = N'PatientsBackupDevice'
Exec pCreatePatientsBackupDevice
Exec pMaintBackupPatients
Exec pRefreshPatientsDev
Exec pTestRestoreFromPatients

Select * From PatientsDev.Sys.Tables
Select * From TempDB.dbo.PatientsMaintLog

-DWClinincReportData
Exec master.dbo.sp_dropdevice @logicalname = N'DWClinicReportDataBackupDevice'
Exec pCreateDWClinicReportDataBackupDevice
Exec pMaintBackupDWClinicReportData
Exec pRefreshDWClinicReportDataDev
Exec pTestRestoreFromDWClinicReportData

Select * From DWClinicReportDataDev.Sys.Tables
Select * From TempDB.dbo.DWClinicReportDataMaintLog
*/
GO

Print 'Store Procedures were successfully created. Check the bottom of the script and follow the instructions to test backups'



