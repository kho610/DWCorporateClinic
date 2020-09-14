--*************************************************************************--
-- Title: OLTP To Data Warehouse ETL
-- Author: Kenton Ho
-- Desc: This script is going to perform various ETL tasks to load our DataWarehouse
--       DWClinicReportData
-- Change Log: When,Who,What
-- 2019-08-20,Kenton,Created ETL Script
--**************************************************************************--

--Data Warehouse 
USE DWClinicReportData
GO

--********************************************************************--
-- Drop the FOREIGN KEY CONSTRAINTS and Truncate all tables
--********************************************************************--

--Drop Foreign Key Procedure
Create Procedure pETLDropForeignKeyConstraints
/* Author: Kenton Ho
** Desc: Removed FKs before truncation of the tables
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

	--DROP FK FactDoctorShifts
	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		Drop Constraint [fkFactDoctorShiftsToDimDates];
	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		Drop Constraint [fkFactDoctorShiftsToDimClinics];
	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		Drop Constraint [fkFactDoctorShiftsToDimShifts];
	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		Drop Constraint [fkFactDoctorShiftsToDimDoctors];

	--DROP FK FactVisits
	Alter Table DWClinicReportData.dbo.FactVisits
		Drop Constraint [fkFactVisitsToDimDates];
	Alter Table DWClinicReportData.dbo.FactVisits
		Drop Constraint [fkFactVisitsToDimClinics];
	Alter Table DWClinicReportData.dbo.FactVisits
		Drop Constraint [fkFactVisitsToDimPatients];
	Alter Table DWClinicReportData.dbo.FactVisits
		Drop Constraint [fkFactVisitsToDimDoctors];
	Alter Table DWClinicReportData.dbo.FactVisits
		Drop Constraint [fkFactVisitsToDimProcedures];

    Print 'Dropping Foreign Key was Successful'
	Set @RC = +1
 End Try
  Begin Catch
	Print Error_Message()
	Set @RC = -1
  End Catch
	Return @RC;
 End
Go

/* Test Code
Declare @Status int;
Exec @Status = pETLDropForeignKeyConstraints;
Print @Status
*/
GO

-----------------------------------------------------------------------------------------------
--Truncate Table Procedures
Create Procedure pETLTruncateTables
/* Author: Kenton Ho
** Desc: Flushes all data from TYPE 1 SCD tables
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --

	--Truncate all Type 1 SCD
	Truncate Table DWClinicReportData.dbo.DimClinics
	Truncate Table DWClinicReportData.dbo.DimDates 
	Truncate Table DWClinicReportData.dbo.DimDoctors
	Truncate Table DWClinicReportData.dbo.DimProcedures
	Truncate Table DWClinicReportData.dbo.DimShifts
	Truncate Table DWClinicReportData.dbo.FactDoctorShifts
	Truncate Table DWClinicReportData.dbo.FactVisits

   Print 'Truncate was Successful'
   Set @RC = +1
 End Try
  Begin Catch
	Print Error_Message()
	Set @RC = -1
  End Catch
	Return @RC;
 End
GO

/* Test Code
Declare @Status int;
Exec @Status = pETLTruncateTables;
Print @Status
*/
Go

--********************************************************************--
-- Transform data through views and FILL the Tables with Sprocs
------------------------DIMENSION TABLES-------------------------------
--********************************************************************--

/******[DimDates] ******/

--Fill DimDates Procedure
Create --Alter
Procedure pETLFillDimDates
	(@StartDateInsert nVarchar(50),
	 @EndDateInsert nVarchar(50))
/* Author: Kenton Ho
** Desc: Inserts data into DimDates
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

    -- ETL Processing Code --
	IF ((Select Count(*) From DimDates) = 0)
	 Begin
      Declare @StartDate datetime = @StartDateInsert
      Declare @EndDate datetime = @EndDateInsert 
      Declare @DateInProcess datetime  = @StartDate
      -- Loop through the dates until you reach the end date
	  While @DateInProcess <= @EndDate
       Begin
       -- Add a row into the date dimension table for this date
       Insert Into DWClinicReportData.dbo.DimDates 
			([DateKey],[FullDate], [FullDateName], [MonthID], [MonthName],[YearID], [YearName] )
       Values ( 
         Cast(Convert(nVarchar(50), @DateInProcess, 112) as int) -- [DateKey]
		,Cast(@DateInProcess as datetime) -- [FullDate]
        ,DateName(weekday, @DateInProcess) + ', ' + Convert(nVarchar(50), @DateInProcess, 0) -- [FullDateName]  
        ,Cast(Left(Convert(nVarchar(50), @DateInProcess, 112), 6) as int)  -- [MonthID]
        ,DateName(month, @DateInProcess) + ' - ' + DateName(YYYY,@DateInProcess) -- [MonthName]
        ,Year(@DateInProcess) -- [YearKey] 
        ,Cast(Year(@DateInProcess ) as nVarchar(50)) -- [YearName] 
        )  
       -- Add a day and loop again
       Set @DateInProcess = DateAdd(d, 1, @DateInProcess)
      End
	  Insert Into DWClinicReportData.dbo.DimDates
			([DateKey], [FullDate], [FullDateName], [MonthID], [MonthName], [YearID], [YearName] )
	  Values
			(-1, Cast(Convert(nvarchar(50), 0, 112) as int), 'Unknown Date', -1, 'Unknown Month', -1, 'Unknown Year')
	  

	 End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/* Testing Code:
 Declare @Status int;
 Exec @Status = pETLFillDimDates
			@StartDateInsert = '01/01/2000',
			@EndDateInsert = '12/31/2020'
 Print @Status;
 Select * From DimDates;
*/
GO

-----------------------------------------------------------------------------------------------
/******[DimClinic] ******/

--DimClinic View
Create View vETLDimClinic
/* Author: Kenton Ho
** Desc: Extracts and transforms data for DimClinic (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
    [ClinicID] = DC.ClinicID, 
	[ClinicName] = CAST(DC.ClinicName as nVarchar(100)), 
	[ClinicCity] = CAST(DC.City as nVarchar(100)), 
	[ClinicState] = CAST(DC.State as nVarchar(100))
  FROM DoctorsSchedules.dbo.Clinics as DC
GO

--DimClinic Fill Store Procedure
Create --Alter
Procedure pETLFillDimClinic
/* Author: Kenton Ho
** Desc: Inserts data into DimClinic using the vETLDimClinic view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

    -- ETL Processing Code --
    IF ((Select Count(*) From DimClinics) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.DimClinics
      ([ClinicID], [ClinicName], [ClinicCity], [ClinicState])
      SELECT
		[ClinicID], [ClinicName], [ClinicCity], [ClinicState]
      FROM vETLDimClinic
    End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillDimClinic;
  Select Case @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillDimProducts]

Select * From DimClinics
*/
GO

-----------------------------------------------------------------------------------------------
/******[DimDoctor] ******/

--DimDoctor View
Create View vETLDimDoctors
/* Author: Kenton Ho
** Desc: Extracts and transforms data for DimDoctor (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
    [DoctorID] = DD.DoctorID,
	[DoctorFullName] = CAST(DD.FirstName + ' ' + DD.LastName as nVarchar(200)),
	[DoctorCity] = CAST(DD.City as nVarchar(100)),
	[DoctorState] = CAST(DD.State as nVarchar(100))
  FROM DoctorsSchedules.dbo.Doctors as DD
GO

--DimDoctor Fill Store Procedure
Create --Alter
Procedure pETLFillDimDoctors
/* Author: Kenton Ho
** Desc: Inserts data into DimClinic using the vETLDimDoctors view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

    -- ETL Processing Code --
    IF ((Select Count(*) From DimDoctors) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.DimDoctors
      ([DoctorID], [DoctorFullName], [DoctorCity], [DoctorState])
      SELECT
		[DoctorID], [DoctorFullName], [DoctorCity], [DoctorState]
      FROM vETLDimDoctors
    End

	--Look up for Null values
	IF NOT EXISTS (SELECT * FROM DimDoctors
                   WHERE DoctorKey = -1
                   )
	Begin
	 SET IDENTITY_INSERT DimDoctors ON
	 Insert Into DWClinicReportData.dbo.DimDoctors
			([DoctorKey], [DoctorID], [DoctorFullName], [DoctorCity], [DoctorState] )
	  Values
			(-1,-1,'Unknown Name', 'Unknown City', 'Unknown State')
	SET IDENTITY_INSERT DimDoctors OFF
	END

   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillDimDoctors;
  Select Case @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillDimDoctors]

Select * From DimDoctors
*/
GO

-----------------------------------------------------------------------------------------------
/******[DimShifts] ******/

--DimShifts View
Create View vETLDimShifts
/* Author: Kenton Ho
** Desc: Extracts and transforms data for DimShifts (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
    [ShiftID] = DS.ShiftID,
	[ShiftStart] = CAST(datepart(hour, ShiftStart) as INT),
	[ShiftEnd] = CAST(datepart(hour, ShiftEnd) as INT)
  FROM DoctorsSchedules.dbo.Shifts as DS
GO



--DimShifts Fill Store Procedure
Create --Alter
Procedure pETLFillDimShifts
/* Author: Kenton Ho
** Desc: Inserts data into DimClinic using the vETLDimShifts view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
	--Update data for ShiftStart and ShiftEnd to make 24 hour clock consistent
	UPDATE DoctorsSchedules.dbo.Shifts
	SET ShiftEnd = '17:00:00'
	WHERE ShiftID = 1

	UPDATE DoctorsSchedules.dbo.Shifts
	SET ShiftStart = '13:00:00'
	WHERE ShiftID = 2

    -- ETL Processing Code --
    IF ((Select Count(*) From DimShifts) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.DimShifts
      ([ShiftID], [ShiftStart], [ShiftEnd])
      SELECT
		[ShiftID], [ShiftStart], [ShiftEnd]
      FROM vETLDimShifts
    End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillDimShifts
  Select Case @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillDimShifts]

Select * From DimShifts
*/
GO
-----------------------------------------------------------------------------------------------
/******[DimProcedures] ******/

--DimProcedures View
Create View vETLDimProcedures
/* Author: Kenton Ho
** Desc: Extracts and transforms data for DimProcedures (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
	[ProcedureID] = PPR.ID,
	[ProcedureName] = CAST(PPR.[Name] as varchar(100)),
	[ProcedureDesc] = CAST(PPR.[Desc] as varchar(1000)),
	[ProcedureCharge] = CAST(PPR.[Charge] as money)
  FROM Patients.dbo.Procedures as PPR
GO

--DimProcedures Fill Store Procedure
Create --Alter
Procedure pETLFillDimProcedures
/* Author: Kenton Ho
** Desc: Inserts data into DimClinic using the vETLDimProcedures view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
    IF ((Select Count(*) From DimProcedures) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.DimProcedures
      ([ProcedureID], [ProcedureName], [ProcedureDesc], [ProcedureCharge])
      SELECT
		[ProcedureID], [ProcedureName], [ProcedureDesc], [ProcedureCharge]
      FROM vETLDimProcedures
    End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillDimProcedures
  Select Case @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillDimProcedures]

Select * From DimProcedures
*/
GO

-----------------------------------------------------------------------------------------------
/******[DimPatients] ******/

--DimPatients View
Create View vETLDimPatients
/* Author: Kenton Ho
** Desc: Extracts and transforms data for DimPatients (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
    [PatientID] = PP.ID,
	[PatientFullName] = CAST(PP.FName + ' ' + PP.LName as varchar(100)),
	[PatientCity] = CAST(PP.City as varchar(100)),
	[PatientState] = CAST(PP.State as varchar(100))
  FROM Patients.dbo.Patients as PP
GO

--DimPatients Incremental Load Store Procedure
Create Procedure pETLSyncDimPatients
/* Author: Kenton
** Desc: Updates data in DimPatients using the vETLDimPatients view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try

    -- ETL Processing Code --

    -- 1) For UPDATE: Change the EndDate and IsCurrent on any added rows 
	With ChangedPatients
	As(
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From vETLDimPatients
		Except
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From DimPatients
		Where IsCurrent = 1 -- Needed if the value is changed back to previous value
	  )
		UPDATE [DWClinicReportData].dbo.DimPatients 
			SET EndDate = GETDATE()
			,IsCurrent = 0
		WHERE PatientID IN (Select PatientID From ChangedPatients)
		;

    -- 2)For INSERT or UPDATES: Add new rows to the table
	With AddedORChangedPatients
	As(
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From vETLDimPatients
		Except
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From DimPatients
		Where IsCurrent = 1 -- Needed if the value is changed back to previous value
	  )
		INSERT INTO [DWClinicReportData].dbo.DimPatients 
			([PatientID], [PatientFullName], [PatientCity], [PatientState], [StartDate], [EndDate], [IsCurrent])
		SELECT
			 [PatientID]
			,[PatientFullName]
			,[PatientCity]
			,[PatientState]
			,[StartDate] = GETDATE()
			,[EndDate] = Null
			,[IsCurrent] = 1
		FROM vETLDimPatients
		WHERE PatientID IN (Select PatientID From AddedORChangedPatients)
		;

    -- 3) For Delete: Change the IsCurrent status to zero
    With DeletedPatients 
	As(
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From DimPatients
		  Where IsCurrent = 1 -- We do not care about row already marked zero!
 		Except            			
		Select [PatientID], [PatientFullName], [PatientCity], [PatientState] From vETLDimPatients
   	  )
		UPDATE [DWClinicReportData].dbo.DimPatients 
			SET EndDate = GETDATE()
			,IsCurrent = 0
		WHERE PatientID IN (Select PatientID From DeletedPatients)
		;

   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
go

/* Testing Code:
 Declare @Status int;
 Exec @Status = pETLSyncDimPatients
 Print @Status;

 Select * From DimPatients Order By PatientID
*/
GO

--********************************************************************--
-- Transform data through views and FILL the Tables with Sprocs
---------------------***FACT TABLES***-------------------------------
--********************************************************************--

/******[FactDoctorShifts] ******/

--FactDoctorShifs View
Create --ALTER 
View vETLFactDoctorShifts
/* Author: Kenton Ho
** Desc: Extracts and transforms data for FactDoctorShifts (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
	[DoctorsShiftID] = DDS.DoctorsShiftID,
	[ShiftDateKey] = DimD.DateKey,
	[ClinicKey] = DimC.ClinicKey,
	[ShiftKey] = DimS.ShiftKey,
	[DoctorKey] = DimDC.DoctorKey,
	[HoursWorked] = DimS.ShiftEnd - DimS.ShiftStart
  FROM DoctorsSchedules.dbo.DoctorShifts as DDS
  JOIN DimDates as DimD
   ON Cast(isNull(Convert(nVarchar(50), DDS.ShiftDate, 112), -1) as int) = DimD.DateKey
  JOIN DimClinics as DimC
   ON DDS.ClinicID = DimC.ClinicID
  JOIN DimShifts as DimS
   ON DDS.ShiftID = DimS.ShiftID
  JOIN DimDoctors as DimDC
   ON DDS.DoctorID = DimDC.DoctorID
GO


--FactDoctorShifts Fill Store Procedure
Create --Alter
Procedure pETLFillFactDoctorShifts
/* Author: Kenton Ho
** Desc: Inserts data into FactDoctorShifts using the vETLFactDoctorShifts view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
    IF ((Select Count(*) From FactDoctorShifts) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.FactDoctorShifts
      ([DoctorsShiftID], [ShiftDateKey], [ClinicKey], [ShiftKey], [DoctorKey], [HoursWorked])
      SELECT
		[DoctorsShiftID], [ShiftDateKey], [ClinicKey], [ShiftKey], [DoctorKey], [HoursWorked]
      FROM vETLFactDoctorShifts
    End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillFactDoctorShifts
  SELECT CASE @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillFactDoctorShifts]

Select * FROM FactDoctorShifts
*/
GO

-----------------------------------------------------------------------------------------------
/******[FactVisits] ******/

--FactDoctorShifs View
Create --ALTER 
View vETLFactVisits
/* Author: Kenton Ho
** Desc: Extracts and transforms data for FactVisits (VIEW)
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created View.
*/
As
  SELECT
	[VisitKey] = PV.ID,
	[DateKey] = DimD.DateKey,
	[ClinicKey] = DimC.ClinicKey,
	[PatientKey] = DimP.PatientKey,
	[DoctorKey] = DimDR.DoctorKey,
	[ProcedureKey] = DimPR.ProcedureKey, 
	[ProcedureVistCharge] = DimPR.ProcedureCharge
  FROM Patients.dbo.Visits as PV
  JOIN DimDates as DimD
   ON DATEADD(dd, DATEDIFF(dd, 0, PV.Date), 0) = DATEADD(dd, DATEDIFF(dd, 0, DimD.FullDate), 0)
  JOIN DimClinics as DimC
   ON PV.Clinic/100 = DimC.ClinicID
  JOIN DimPatients as DimP
   ON PV.Patient = DimP.PatientID
  JOIN DimDoctors as DimDR
   ON Cast(isNull(Convert(nVarchar(50), PV.Doctor, 112), -1) as int)= DimDR.DoctorID
  JOIN DimProcedures as DimPR
   ON PV.[Procedure] = DimPR.ProcedureID
GO

--FactVisits Fill Store Procedure
Create --Alter
Procedure pETLFillFactVisits
/* Author: Kenton Ho
** Desc: Inserts data into FactVisits using the vETLFactVisits view
** Change Log: When,Who,What
** 2019-08-20,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
    -- ETL Processing Code --
    IF ((Select Count(*) From FactVisits) = 0)
     Begin
      INSERT INTO [DWClinicReportData].dbo.FactVisits
      ([VisitKey], [DateKey], [ClinicKey], [PatientKey], [DoctorKey], [ProcedureKey], [ProcedureVistCharge])
      SELECT
		[VisitKey],[DateKey], [ClinicKey], [PatientKey], [DoctorKey], [ProcedureKey], [ProcedureVistCharge]
      FROM vETLFactVisits
    End
   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/*Test Code
Declare @Status int;
Exec @Status = pETLFillFactVisits
  SELECT CASE @Status
	When +1 Then 'Successful!'
	When -1 Then 'Failed'
  End as [pETLFillFactVisits]

Select * FROM FactVisits
*/
GO

--********************************************************************--
-- Re-Create the FOREIGN KEY CONSTRAINTS
--********************************************************************--

Create --Alter 
Procedure pETLAddForeignKeyConstraints
/* Author: Kenton HO
** Desc: Re-Add FKs After tables are fulled
** Change Log: When,Who,What
** 20189-08-02,Kenton Ho,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
 
	  --DROP FK FactDoctorShifts
	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		Add Constraint [fkFactDoctorShiftsToDimDates]
		  FOREIGN KEY (ShiftDateKey) REFERENCES DimDates(DateKey)

	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		ADD Constraint [fkFactDoctorShiftsToDimClinics]
		  FOREIGN KEY (ClinicKey) REFERENCES DimClinics(ClinicKey)

	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		ADD Constraint [fkFactDoctorShiftsToDimShifts]
		  FOREIGN KEY (ShiftKey) REFERENCES DimShifts(ShiftKey)

	Alter Table DWClinicReportData.dbo.FactDoctorShifts
		ADD Constraint [fkFactDoctorShiftsToDimDoctors]
		  FOREIGN KEY (DoctorKey) REFERENCES DimDoctors(DoctorKey)

	--DROP FK FactVisits
	Alter Table DWClinicReportData.dbo.FactVisits
		ADD Constraint [fkFactVisitsToDimDates]
		  FOREIGN KEY (DateKey) REFERENCES DimDates(DateKey)

	Alter Table DWClinicReportData.dbo.FactVisits
		ADD Constraint [fkFactVisitsToDimClinics]
		  FOREIGN KEY (ClinicKey) REFERENCES DimClinics(ClinicKey)

	Alter Table DWClinicReportData.dbo.FactVisits
		ADD Constraint [fkFactVisitsToDimPatients]
		  FOREIGN KEY (PatientKey) REFERENCES DimPatients(PatientKey)

	Alter Table DWClinicReportData.dbo.FactVisits
		ADD Constraint [fkFactVisitsToDimDoctors]
		  FOREIGN KEY (DoctorKey) REFERENCES DimDoctors(DoctorKey)

	Alter Table DWClinicReportData.dbo.FactVisits
		ADD Constraint [fkFactVisitsToDimProcedures]
		  FOREIGN KEY (ProcedureKey) REFERENCES DimProcedures(ProcedureKey)

   Set @RC = +1
  End Try
  Begin Catch
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
GO

/* Testing Code:
 Declare @Status int;
 Exec @Status = pETLAddForeignKeyConstraints;
 Print @Status;
*/
GO

--********************************************************************--
-- Code Executions 
--********************************************************************--

Declare @Status int;
Exec @Status = pETLDropForeignKeyConstraints;
Select [Object] = 'pETLDropForeignKeyConstraints', [Status] = @Status;

Exec @Status = pETLTruncateTables;
Select [Object] = 'pETLTruncateTables', [Status] = @Status;

Exec @Status = pETLFillDimDates
			@StartDateInsert = '01/01/2000',
			@EndDateInsert = '12/31/2020'
Select [Object] = 'pETLFillDimDates', [Status] = @Status;

Exec @Status = pETLFillDimClinic;
Select [Object] = 'pETLFillDimClinic', [Status] = @Status;

Exec @Status = pETLFillDimDoctors;
Select [Object] = 'pETLFillDimDoctors', [Status] = @Status;

Exec @Status = pETLFillDimShifts;
Select [Object] = 'pETLFillDimShifts', [Status] = @Status;

Exec @Status = pETLFillDimProcedures;
Select [Object] = 'pETLFillDimProcedures', [Status] = @Status;

Exec @Status = pETLSyncDimPatients;
Select [Object] = 'pETLSyncDimPatients', [Status] = @Status;

Exec @Status = pETLFillFactDoctorShifts;
Select [Object] = 'pETLFillFactDoctorShifts', [Status] = @Status;

Exec @Status = pETLFillFactVisits;
Select [Object] = 'pETLFillFactVisits', [Status] = @Status;

Exec @Status = pETLAddForeignKeyConstraints;
Select [Object] = 'pETLAddForeignKeyConstraints', [Status] = @Status;



SELECT * FROM DimClinics
SELECT * FROM DimDates
SELECT * FROM DimDoctors
SELECT * FROM DimPatients
SELECT * FROM DimShifts
SELECT * FROM FactDoctorShifts
SELECT * FROM FactVisits