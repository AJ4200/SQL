CREATE OR ALTER PROCEDURE [dbo].[spAcceptRequest]
	@request INT
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		28 July 2022  
	-- Description:		Updates a request when a driver accepts the request
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	UPDATE [dbo].[Request]
	SET [Received] = 1
	WHERE [RequestNumber] = @request

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spArrivedAtControlStation]
	@request INT
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		02 August 2022  
	-- Description:		Updates the arrival date and time of a truck when fulfilling a request
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	UPDATE [dbo].[Collection]
	SET [ArrivedAtControlStation] = GETDATE()
	WHERE [Request] = @request;

	DECLARE @driver CHAR(6);
	SELECT @driver = Driver FROM [dbo].[Collection] WHERE Request=@request;
	EXEC [dbo].[spEnqueueTruck] @driver;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spArrivedAtGardenSite]
	@request INT,
	@gsBin CHAR(8)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		02 August 2022  
	-- Description:		Updates the arrival date and time of a truck when fulfilling a request
	-- Change Histrory: 219023735, 03 August 2022 - Added functionality to exchange bins
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @trBin CHAR(8);
	
	SELECT @trBin = [Bin]
	FROM [dbo].[Truck]
	WHERE [TruckID] IN (
		SELECT [Truck] FROM [dbo].[Collection]
		WHERE [Request]=@request
	)

	UPDATE [dbo].[Collection]
	SET [ArrivedAtGardenSite] = GETDATE()
	WHERE [Request] = @request

	UPDATE [dbo].[BinSlot]
	SET [Bin]=@trBin
	WHERE [Bin]=@gsBin

	UPDATE [dbo].[Truck]
	SET [Bin]=@gsBin
	WHERE [Bin]=@trBin

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spArrivedAtLandfill]
	@request INT
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		02 August 2022  
	-- Description:		Updates the arrival date and time of a truck when fulfilling a request
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	UPDATE [dbo].[Collection]
	SET [ArrivedAtLandfill] = GETDATE()
	WHERE [Request] = @request

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spArrivedAtReportedTruck]
	@request INT,
	@trBin CHAR(8)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		18 October 2022  
	-- Description:		Swaps bins of reported truck and new truck
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	--get broken downtruck bin and ID
	DECLARE @newTruck CHAR(3);
	DECLARE @btTruck CHAR(3);
	
	SELECT @newTruck=[Truck] FROM [dbo].[Collection]
	WHERE [Request]=@request;
	
	SELECT @btTruck=[Truck] FROM [dbo].[TruckIssue]
	WHERE [Request]=@request;
	
	--swap bins
	UPDATE [dbo].[Truck]
	SET [Bin]=@trBin
	WHERE [TruckID]=@newTruck;
	
	UPDATE [dbo].[Truck]
	SET [Bin]=NULL
	WHERE [TruckID]=@btTruck;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spCurrentMonthCollectionLog]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 July 2022  
	-- Description:		Fetches number of collections from each month
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT CollectionNumber, Driver, SentTo, Waste, Supervisor, CollectionDate 
	FROM [dbo].[CollectionLog]
	WHERE DATENAME(month,[CollectionDate]) = DATENAME(month,getDate())

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spCurrentMonthOverview]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		08 September 2022 
	-- Description:		Returns the number of collections and breakdowns of the current month
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @spCol TABLE([Waste] NVARCHAR(50), [Month] NVARCHAR(20), [Collected] INT, [Tonnage] DECIMAL(18,5));
	DECLARE @spRec TABLE([Waste] NVARCHAR(50), [Month] NVARCHAR(20), [Collected] INT, [Tonnage] DECIMAL(18,5));
	DECLARE @cols TABLE([Loads] INT, Tonnage DECIMAL(18,5));
	DECLARE @recs TABLE([Loads] INT, Tonnage DECIMAL(18,5));
	DECLARE @landfillLoads INT, @landfillTonnage DECIMAL(18,5);
	DECLARE @recycledLoads INT, @recycledTonnage DECIMAL(18,5);
	DECLARE @breakdowns INT;
	
	--get collected
	INSERT INTO @spCol([Waste], [Month], [Collected], [Tonnage])
	EXEC [dbo].[spWasteDroppedOff];

	INSERT INTO @cols([Loads], [Tonnage]) (
	SELECT SUM([Collected]), SUM(CAST([Tonnage] AS DECIMAL(18,5)))
	FROM @spCol
	WHERE [Month]=DATENAME(mm,GETDATE())
	GROUP BY [Month], [Collected]);

	SELECT @landfillLoads=SUM([Loads]), @landfillTonnage=SUM([Tonnage]) FROM @cols;

	--get recycled
	INSERT INTO @spRec([Waste], [Month], [Collected], [Tonnage])
	EXEC [dbo].[spWasteDroppedOff] 1;

	INSERT INTO @recs([Loads], [Tonnage]) (
	SELECT SUM([Collected]), SUM(CAST([Tonnage] AS DECIMAL(18,5)))
	FROM @spRec
	WHERE [Month]=DATENAME(mm,GETDATE())
	GROUP BY [Month], [Collected]);

	SELECT @recycledLoads=SUM([Loads]), @recycledTonnage= SUM([Tonnage]) FROM @recs;

	--get Breakdowns
	DECLARE @to DATETIME = GETDATE();
	DECLARE @from DATETIME = DATEADD(month,-1,@to);
	
	SELECT @breakdowns=COUNT(*)
	FROM [dbo].[TruckIssue]
	WHERE [ReportedAt]>=@from AND [ReportedAt]<=@to

	SELECT @landfillLoads AS [LandfillLoads], @landfillTonnage  AS [LandfillTonnage], 
		@recycledLoads AS [RecycledLoads], @recycledTonnage AS [RecycledTonnage], @breakdowns AS [Breakdowns]

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spDequeueDriver]
	@driver CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		05 October 2022  
	-- Description:		Removes a truck from the queue
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @truck CHAR(3);
	SELECT @truck=TruckID FROM [dbo].[Truck]
	WHERE Driver=@driver;
	
	DELETE [dbo].[TruckQueue]
	WHERE [Truck]=@truck;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spDequeueTruck]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		26 July 2022  
	-- Description:		Returns the truck in front of the queue
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @output TABLE (ID UNIQUEIDENTIFIER, Truck CHAR(3));
	
	WITH PoppedItem(Id, Truck, ProcessingStartedAt) AS (
	    SELECT TOP(1) tQueue.[Id], tQueue.[Truck], tQueue.[ProcessingStartedAt]
	    FROM [dbo].[TruckQueue] tQueue WITH (READPAST, UPDLOCK)
    	WHERE tQueue.[ProcessingStartedAt] IS NULL
    	ORDER BY tQueue.[CreatedAt]
	)
	UPDATE PoppedItem SET ProcessingStartedAt = GETDATE()
	output inserted.ID, inserted.Truck into @output;

	IF (EXISTS(SELECT 1 FROM @output))
	BEGIN
		DELETE FROM [TruckQueue] 
		WHERE [Id] IN (SELECT ID FROM @output);
	END
	SELECT * FROM @output
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spEnqueueTruck]
	@driver CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		27 July 2022  
	-- Description:		Adds a truck to the back of the queue
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @truck CHAR(3);
	SELECT @truck=TruckID FROM [dbo].[Truck]
	WHERE Driver=@driver
	
	IF(NOT (EXISTS(SELECT 1 FROM [dbo].[TruckQueue] WHERE [Truck]=@truck)
		OR EXISTS(SELECT 1 FROM [dbo].[Collection] WHERE [Truck]=@truck AND [ArrivedAtControlStation] IS NULL)
		OR EXISTS(SELECT 1 FROM [dbo].[TruckIssue] WHERE [Fixed]=0 AND [Truck]=@truck)))
	BEGIN
		INSERT INTO [dbo].[TruckQueue] (Id, CreatedAt, Truck)
		VALUES (NEWID(), GETDATE(), @truck);

		IF(EXISTS(SELECT 1 FROM [dbo].[TruckQueue])) 
		BEGIN
			EXEC [dbo].[spProcessRequest];
		END;
	END;
	
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spGardenSiteTraffic] 
	@startDate DateTime, 
	@EndDate DateTime
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		11 July 2022  
	-- Description:		Fetches number of requests made by each garden site
	-- Change Histrory: S Mazibuko, 08 September 2022 - Groups garden sites into areas
	-- Change Histrory: EK Cloete, 19 September 2022 - Added a Date Range
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @Areas TABLE (Area NVARCHAR(50));
	INSERT @Areas(Area) VALUES('Soweto'),('Randburg'),('Roodepoort'),('Lenasia'),
		('Zakariyya Park'),('Midrand'),('Sandton'),('Johannesburg South'),('Johannesburg');

	SELECT a.Area, COALESCE(b.NumberOfRequests, 0) AS [Requests]
	FROM @Areas a
	LEFT JOIN (
		SELECT ar.[Area], COUNT(ar.[Area]) AS [NumberOfRequests]
		FROM @Areas ar
		LEFT JOIN [dbo].[Location] loc ON loc.[Address] LIKE '%'+ar.[Area]+',%'
		INNER JOIN [dbo].[Request] req ON req.[GardenSite] = loc.[LocationID]
		WHERE loc.[dtype]='Garden Site'
		AND req.[RequestDate] >= @startDate AND req.[RequestDate] <=@EndDate 
		GROUP BY ar.[Area] 
	) b ON a.Area = b.Area

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spMoblieCredentials]
	@staff CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		26 July 2022  
	-- Description:		Gets attributes for mobile application's session variables
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT TOP(1) [StaffID], stf.[dtype], [Email], [Telephone], [LocationID], [Address]
	FROM [dbo].[Staff] stf LEFT JOIN [dbo].[Location]
	ON [StaffID] = [Supervisor]
	WHERE [StaffID] = @staff

END
GO

--needs to be decomposed for recycled and collected
CREATE OR ALTER PROCEDURE [dbo].[spMonthlyCollections]
	@startDate DATETIME,
	@endDate DATETIME
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		13 July 2022  
	-- Description:		Fetches number of collections from each month
	-- Change Histrory: 219023735, 14 July 2022 - Returns month names instead of the month's number
	-- Change Histrory: 219023735, 29 September 2022 - Returns data from the past 12 months
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	WITH months(MonthNumber) AS
	(
		SELECT 0
		UNION ALL
		SELECT MonthNumber+1
		FROM months
		WHERE MonthNumber < 11
	)
	SELECT FORMAT(DATEADD(MONTH,-MonthNumber,GETDATE()),'MMMM') AS [Month], 
		COALESCE(COUNT(MONTH([CollectionDate])), 0) AS [Amount]
	FROM (
		SELECT [CollectionDate] FROM [dbo].[CollectionLog]
		WHERE [CollectionDate]>=@startDate AND [CollectionDate]<=@endDate
	) col
	RIGHT JOIN months ON ((MONTH(GETDATE())-[MonthNumber])%12)=MONTH([CollectionDate])
	GROUP BY MONTH([CollectionDate]), [MonthNumber]
	ORDER BY [MonthNumber] DESC;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spPendingRequests]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 July 2022  
	-- Description:		Fetches all requests that have not been completed
	-- Change Histrory: 219023735, 04 August 2022 - Return names instead of IDs
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT [RequestNumber], [Bin], wa.[Name] AS [Waste], gs.[Address] AS [GardenSite],
		CONCAT(su.[Name], ' ', su.[Surname]) AS [Supervisor], [RequestDate]
	FROM [dbo].[Request]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	INNER JOIN [dbo].[Staff] su ON [Supervisor]=su.[StaffID]
	INNER JOIN [dbo].[Location] gs ON [GardenSite]=gs.[LocationID]
	WHERE [RequestNumber] IN (
		SELECT [Request]
			FROM [dbo].[Collection]
			WHERE [ArrivedAtGardenSite] IS NULL
	)

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spPendingRequestsFor]
	@supervisor CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		03 August 2022  
	-- Description:		Fetches all pending requests for a garden site
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @pending TABLE([RequestNumber] INT, [Bin] NVARCHAR(8), [Waste] NVARCHAR(50), [RequestedAt] DATETIME, [Status] NVARCHAR(10));
	INSERT INTO @pending ([RequestNumber], [Bin], [Waste], [RequestedAt], [Status])
	SELECT [RequestNumber], [Bin], wa.[Name] AS [Waste], [RequestDate] AS [RequestedAt],
		[Status]=	CASE
						WHEN [Received]=1 THEN 'En Route'
						WHEN DATEDIFF(day, [RequestDate], GETDATE())>=1 THEN 'Overdue'
						ELSE 'Waiting'
					END 
	FROM [dbo].[Request]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	WHERE [RequestNumber] IN (
		SELECT [Request]
			FROM [dbo].[Collection]
			WHERE [ArrivedAtGardenSite] IS NULL
	) 
	AND [Supervisor]=@supervisor

	INSERT INTO @pending ([RequestNumber], [Bin], [Waste], [RequestedAt], [Status])
	SELECT [RequestNumber]=0, [Bin], wa.[Name] AS [Waste], [CreatedAt] AS [RequestedAt], [Status]='Waiting'
	FROM [dbo].[RequestBuffer]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	WHERE [Supervisor]=@supervisor
	
	SELECT * FROM @pending

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spProcessNewRequest]
AS
BEGIN
	DECLARE @output TABLE (ID UNIQUEIDENTIFIER, RequestDate DATETIME, Bin CHAR(8), Waste NVARCHAR(50), GardenSite CHAR(5), 
			Supervisor CHAR(6));
	
	DECLARE @dequeuedtruck TABLE (ID UNIQUEIDENTIFIER, Truck CHAR(3));
	DECLARE @destResult TABLE ([Destination] CHAR(5));
	DECLARE @truck CHAR(3);
	DECLARE @driver CHAR(6);
	DECLARE @request INT;
	DECLARE @dest CHAR(5);
	DECLARE @waste NVARCHAR(50);

	--pop from buffer
	WITH PoppedItem(Id, CreatedAt, Bin, Waste, GardenSite, Supervisor, ProcessingStartedAt) AS (
	    SELECT TOP(1) rBuffer.[Id], rBuffer.[CreatedAt], rBuffer.[Bin], rBuffer.[Waste], rBuffer.[GardenSite], 
				rBuffer.[Supervisor], rBuffer.[ProcessingStartedAt]
	    FROM [dbo].[RequestBuffer] rBuffer WITH (READPAST, UPDLOCK)
    	WHERE rBuffer.[ProcessingStartedAt] IS NULL
    	ORDER BY rBuffer.[CreatedAt]
	)
	UPDATE PoppedItem SET ProcessingStartedAt = GETDATE()
	output inserted.Id, inserted.CreatedAt, inserted.Bin, inserted.Waste, inserted.GardenSite, inserted.Supervisor into @output

	--if there was at least 1 item in buffer
	IF (EXISTS(SELECT 1 FROM @output))
	BEGIN
		DELETE FROM [dbo].[RequestBuffer] 
		WHERE [Id] IN (SELECT ID FROM @output);
		
		SELECT @waste=[Name] FROM [dbo].[Waste] 
		INNER JOIN @output ON [WasteNumber]=[Waste];
		INSERT INTO @destResult
		exec spGetDestination @waste;
		SELECT @dest=[Destination] FROM @destResult;

		INSERT INTO [dbo].[Request] (Bin, Waste, GardenSite, Supervisor, RequestDate)
		SELECT Bin, Waste, GardenSite, Supervisor, RequestDate
		FROM @output;

		INSERT INTO @dequeuedtruck(ID, Truck)
		EXEC [dbo].[spDequeueTruck];

		SELECT @truck = Truck FROM @dequeuedtruck;
		
		SELECT @driver = Driver FROM [dbo].[Truck] 	WHERE [TruckID] = @truck;

		SELECT @request=RequestNumber FROM [dbo].[Request]
		WHERE Waste IN (SELECT [Waste] FROM @output )
			AND GardenSite IN (SELECT [GardenSite] FROM @output )
			AND RequestDate IN (SELECT [RequestDate] FROM @output )
			AND Supervisor IN (SELECT [Supervisor] FROM @output );

		INSERT INTO [dbo].[Collection] (Truck, Driver, Destination, Request)
		VALUES (@truck, @driver, @dest, @request)
	END
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spProcessReported]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 August 2022  
	-- Description:		Processes a reported request from the buffer
	-- Change Histrory: Name, Date - Description
	-- =================================================
	
	DECLARE @dequeuedrequest TABLE (ID UNIQUEIDENTIFIER, Request INT, 
		ArrivedAtGardenSite DATETIME);
	DECLARE @dequeuedtruck TABLE (ID UNIQUEIDENTIFIER, Truck CHAR(3));
	DECLARE @truck CHAR(3);
	DECLARE @driver CHAR(6);

	--pop from buffer
	WITH PoppedItem(Id, CreatedAt, Request, ProcessingStartedAt, ArrivedAtGardenSite) AS (
	    SELECT TOP(1) rBuffer.[Id], rBuffer.[CreatedAt], rBuffer.[Request], rBuffer.[ProcessingStartedAt], rBuffer.[ArrivedAtGardenSite]
	    FROM [dbo].[ReportBuffer] rBuffer WITH (READPAST, UPDLOCK)
    	WHERE rBuffer.[ProcessingStartedAt] IS NULL
    	ORDER BY rBuffer.[CreatedAt]
	)
	UPDATE PoppedItem SET ProcessingStartedAt = GETDATE()
	output inserted.Id, inserted.Request, inserted.ArrivedAtGardenSite into @dequeuedrequest

	--if there was at least 1 item in buffer
	IF (EXISTS(SELECT 1 FROM @dequeuedrequest))
	BEGIN
		DELETE FROM [dbo].[ReportBuffer] 
		WHERE [Id] IN (SELECT ID FROM @dequeuedrequest);

		INSERT INTO @dequeuedtruck(ID, Truck)
		EXEC [dbo].[spDequeueTruck];

		SELECT @truck=[Truck] FROM @dequeuedtruck;
		
		SELECT @driver=[Driver] FROM [dbo].[Truck]
		WHERE [TruckID] = @truck;
		
		UPDATE [dbo].[Collection]
		SET [Truck]=@truck, [Driver]=@driver
		WHERE [Request] IN (
			SELECT [Request] FROM @dequeuedrequest
		);
	END
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spProcessRequest]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		27 July 2022  
	-- Description:		Processes a request from the buffer
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	IF (EXISTS(SELECT 1 FROM [dbo].[ReportBuffer]))
	BEGIN
		EXEC [dbo].[spProcessReported];
	END
	ELSE
	BEGIN
		EXEC [dbo].[spProcessNewRequest];
	END;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spReportTruckIssue]
	@request INT,
	@location NVARCHAR(150)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 August 2022  
	-- Description:		Reporting function for when a driver is unable to fulfill a request
	-- Change Histrory: S Mazibuko, 08 September 2022 - reported truck becomes unavailable
	-- Change Histrory: S Mazibuko, 23 September 2022 - reverted previous change and added what the cause was
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @toGS DATETIME;
	DECLARE @toLF DATETIME;
	DECLARE @truck CHAR(3);
	DECLARE @driver CHAR(6);

	SELECT @toGS=[ArrivedAtGardenSite], @toLF=[ArrivedAtLandfill], @truck=[Truck],
		@driver=[Driver]
	FROM [dbo].[Collection]
	WHERE [Request]=@request

	IF(@toGS IS NULL OR @toLF IS NULL) 
	BEGIN
		UPDATE [dbo].[Collection]
		SET [Driver]=NULL, [Truck]=NULL
		WHERE [Request]=@request
		
		INSERT INTO [dbo].[TruckIssue] (Id, Truck, Driver, Request, ReportedAt, Location)
		VALUES (NEWID(), @truck, @driver, @request, GETDATE(), @location)
		
		INSERT INTO [dbo].[ReportBuffer] (Id, CreatedAt, Request, ArrivedAtGardenSite)
		VALUES (NEWID(), GETDATE(), @request, @toGS)
		
		IF(EXISTS(SELECT 1 FROM [dbo].[TruckQueue])) 
		BEGIN
			EXEC [dbo].[spProcessRequest];
		END;
	END
	ELSE
	BEGIN
		EXEC [dbo].[spArrivedAtControlStation] @request;
	END;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spRequestCollection]
	@bin CHAR(8),
	@waste NVARCHAR(50),
	@gardenSite CHAR(5),
	@supervisor CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		27 July 2022  
	-- Description:		Adds a request for collection into the buffer
	-- Change Histrory: S Mazibuko, 09 September 2022 - insert recyclables into recycle request
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @validScan BIT;
	DECLARE @wasteID INT;
	DECLARE @bufferID UNIQUEIDENTIFIER = NEWID();
	DECLARE @duplicate TABLE([Bin] CHAR(8));
	
	SELECT @validScan = 
		CASE
			WHEN COUNT(*) > 0 THEN CONVERT(BIT, 1)
			ELSE CONVERT(BIT, 0)
		END
	FROM [dbo].[BinSlot]
	WHERE [Bin]=@bin AND [GardenSite]=@gardenSite;
	
	INSERT INTO @duplicate ([Bin])
	SELECT [Bin] FROM [dbo].[RequestBuffer] WHERE [BIN]=@bin;
	
	INSERT INTO @duplicate ([Bin])
	SELECT req.[Bin] FROM [dbo].[Request] req 
	INNER JOIN [dbo].[Collection] col ON req.[RequestNumber]=col.[Request]
	WHERE req.[BIN]=@bin AND col.[ArrivedAtGardenSite] IS NULL
	
	IF(@validScan = 0) 
	BEGIN
		SELECT [Status]='Invalid Bin';
	END
	ELSE IF(EXISTS(SELECT 1 FROM @duplicate)) 
	BEGIN
		SELECT [Status]='Duplicate';
	END
	ELSE
	BEGIN
		SELECT @wasteID = [WasteNumber]
		FROM [dbo].[Waste] WHERE [Name]=@waste;

		INSERT INTO [dbo].[RequestBuffer] (Id, CreatedAt, Bin, Waste, GardenSite, Supervisor)
		VALUES(@bufferID, GETDATE(), @bin, @wasteID, @gardenSite, @supervisor);

		IF(EXISTS(SELECT 1 FROM [dbo].[TruckQueue])) 
		BEGIN
			EXEC [dbo].[spProcessRequest];
		END;
		
		SELECT [Status]='Success';
	END;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spSearchRequestFor]
	@driver CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		27 July 2022  
	-- Description:		Returns requests allocated to driver
	-- Change Histrory: S Mazibuko, 08 September 2022 - also returns whether there was a truck breakdown
	-- Change Histrory: S Mazibuko, 09 September 2022 - returns pickup and dropoff points
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @request INT;
	DECLARE @atCS DATETIME;
	DECLARE @pickup NVARCHAR(150);
	
	SELECT TOP(1) @request=[Request], @atCS=[ArrivedAtControlStation]
	FROM [dbo].[Collection]
	WHERE [Driver]=@driver AND [ArrivedAtControlStation] IS NULL
	
	SELECT TOP(1) @pickup=[Location]
	FROM [dbo].[TruckIssue]
	WHERE [Request]=@request
	ORDER BY [ReportedAt] DESC;
	
	SELECT req.[RequestNumber], req.[Bin], req.[Waste], req.[PickUpPoint], req.[DropOffPoint], req.[Received], [Reported]
	FROM [dbo].[Collection] col
	INNER JOIN (
		SELECT [RequestNumber], [Bin], wst.[Name] AS [Waste], drp.[Address] AS [DropOffPoint], [Received], 
			[PickUpPoint] =
				CASE
					WHEN @pickup IS NOT NULL THEN @pickup
					ELSE pck.[Address]
				END,
			[Reported] = 
				CASE
					WHEN ti.[Id] IS NOT NULL THEN CONVERT(BIT, 1)
					ELSE CONVERT(BIT, 0)
				END
		FROM [dbo].[Request] 
		LEFT JOIN [dbo].[Collection] col ON [RequestNumber]=col.[Request]
		LEFT JOIN [dbo].[Location] drp ON col.[Destination]= drp.[LocationID]
		LEFT JOIN [dbo].[Location] pck ON [GardenSite]= pck.[LocationID]
		LEFT JOIN [dbo].[Waste] wst ON [Waste]=wst.[WasteNumber]
		LEFT JOIN [dbo].[TruckIssue] ti ON col.[Request]=ti.[Request]
		WHERE col.[Request]=@request
	) req ON col.[Request]=req.[RequestNumber]
	WHERE col.[Driver]=@driver AND col.[ArrivedAtControlStation] IS NULL;

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spTotalCollectionsBy]
	@driver CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		04 August 2022  
	-- Description:		Gets total requests fulfilled by a driver
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT CONCAT([Name], ' ', [Surname]) AS [Driver], (COUNT(col.[Driver])) AS [CollectionsCompleted],
		[Breakdowns] = (SELECT COUNT([Driver]) FROM [dbo].[TruckIssue] WHERE [Driver]=@driver)
	FROM [dbo].[CollectionLog] col
	RIGHT JOIN [dbo].[Driver] ON CONCAT([Name], ' ', [Surname])=col.[Driver]
	WHERE [StaffID]=@driver
	GROUP BY [Name], [Surname], col.[Driver]
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spTotalRequestsBy]
	@supervisor CHAR(6)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		04 August 2022  
	-- Description:		Gets total requests made by a supervisor
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT CONCAT([Name], ' ', [Surname]) AS [Supervisor], (COUNT(col.[Supervisor])) AS [RequestsMade]
	FROM [dbo].[CollectionLog] col
	RIGHT JOIN [dbo].[Supervisor] ON CONCAT([Name], ' ', [Surname])=col.[Supervisor]
	WHERE [StaffID]=@supervisor
	GROUP BY [Name], [Surname], col.[Supervisor]
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spTruckBreakdowns]
	@startDate DATETIME,
	@endDate DATETIME
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		08 September 2022 
	-- Description:		Gets statistics on truck breakdowns
	-- Change Histrory: S Mazibuko, 20 September 2022 - Added area in return and date ranges
	-- Change Histrory: S Mazibuko, 23 September 2022 - Reverted previous change and return NumberPlates and Date of breakdown
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	WITH months(MonthNumber) AS
	(
		SELECT 0
		UNION ALL
		SELECT MonthNumber+1
		FROM months
		WHERE MonthNumber < 11
	)
	SELECT FORMAT(DATEADD(MONTH,-MonthNumber,GETDATE()),'MMMM') AS [Month], 
		COALESCE(COUNT(MONTH([ReportedAt])), 0) AS [Breakdowns]
	FROM (
		SELECT [ReportedAt] FROM [dbo].[TruckIssue]
		WHERE [ReportedAt]>=@startDate AND [ReportedAt]<=@endDate
	) ti
	RIGHT JOIN months ON ((MONTH(GETDATE())-[MonthNumber])%12)=MONTH([ReportedAt])
	GROUP BY MONTH([ReportedAt]), [MonthNumber]
	ORDER BY [MonthNumber] DESC;
	
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spTruckQueue]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 July 2022  
	-- Description:		Fetches truck queue information for viewing
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT tr.[NumberPlate] AS [Truck], tr.[Driver], tq.[CreatedAt] AS [Entered]
	FROM [dbo].[TruckQueue] tq
	INNER JOIN [dbo].[TruckView] tr ON tq.[Truck]=tr.[TruckID]
	ORDER BY tq.[CreatedAt];
	
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spUnavailableTrucks]
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		15 July 2022  
	-- Description:		Fetches number of collections from each month
	-- Change Histrory: S Mazibuko, 23 September 2022 - returns the number of days the truck has been unavailable
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	SELECT tr.[NumberPlate] AS [Truck], DATEDIFF(DAY, ti.[ReportedAt], GETDATE()) AS [DaysUnavailable]
	FROM [dbo].[TruckIssue] ti
	INNER JOIN [dbo].[Truck] tr ON ti.[Truck]=tr.[TruckID]
	WHERE ti.[Fixed] = 0

END
GO

CREATE OR ALTER PROCEDURE [dbo].[spWasteDroppedOff]
	@atRecycler BIT = 0
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		25 August 2022  
	-- Description:		Gets the amount of containers dumped at landfills or recyclers
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	IF(@atRecycler=0)
	BEGIN
		WITH months(MonthNumber) AS
		(
			SELECT 0
			UNION ALL
			SELECT MonthNumber+1
			FROM months
			WHERE MonthNumber < 11
		)
		SELECT [Name] AS [WasteType],FORMAT(DATEADD(MONTH,-MonthNumber,GETDATE()),'MMMM') AS [Month], 
			COUNT(col.[Waste]) AS [NumberOfLoads], (COUNT(col.[Waste])*[Weight]) AS [Tonnage]
		FROM [dbo].[Waste] CROSS JOIN months
		LEFT JOIN (
			SELECT Waste, Month([CollectionDate]) AS [MonthName]
			FROM [dbo].[CollectionLog]
			WHERE [CollectionDate] >= DATEADD(year,-1,GETDATE())
		) col ON ((MONTH(GETDATE())-[MonthNumber])%12)=col.[MonthName] AND [Name]=col.[Waste]
		WHERE [Name] != 'None' 
		GROUP BY [MonthNumber], col.[Waste], [Name], [Weight];
	END
	ELSE
	BEGIN
		WITH months(MonthNumber) AS
		(
			SELECT 0
			UNION ALL
			SELECT MonthNumber+1
			FROM months
			WHERE MonthNumber < 11
		)
		SELECT [Name] AS [WasteType],FORMAT(DATEADD(MONTH,-MonthNumber,GETDATE()),'MMMM') AS [Month], 
			COUNT(col.[Waste]) AS [NumberOfLoads], (COUNT(col.[Waste])*[Weight]) AS [Tonnage]
		FROM [dbo].[Waste] CROSS JOIN months
		LEFT JOIN (
			SELECT Waste, Month([CollectionDate]) AS [MonthName]
			FROM [dbo].[CollectionLog]
			WHERE [Recycled]=@atRecycler AND [CollectionDate] >= DATEADD(year,-1,GETDATE())
		) col ON ((MONTH(GETDATE())-[MonthNumber])%12)=col.[MonthName] AND [Name]=col.[Waste]
		WHERE [Name] != 'None' 
		GROUP BY [MonthNumber], col.[Waste], [Name], [Weight];
	END
	
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spGetDestination]
	@waste NVARCHAR(50)
AS
BEGIN
	-- =================================================  
	-- Author:			S Mazibuko, 219023735
	-- Create date:		04 October 2022  
	-- Description:		Gets destination for collection
	-- Change Histrory: Name, Date - Description
	-- =================================================
	--Prevents extra results from interfering with statements
	SET NOCOUNT ON;

	DECLARE @dest CHAR(5);

	IF(@waste = 'Industrial Waste')
	BEGIN 
		SELECT @dest=[RecyclerID] FROM (
			SELECT 
			[RecyclerID], ROW_NUMBER() OVER(ORDER BY [RecyclerID]) AS [ROW]
			FROM [dbo].[Recycler] WHERE [IndustrialWaste]=1
		) AS temp
		GROUP BY [ROW], [RecyclerID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END
	ELSE IF(@waste = 'Cardboard and Paper')
	BEGIN 
		SELECT @dest=[RecyclerID] FROM (
			SELECT 
			[RecyclerID], ROW_NUMBER() OVER(ORDER BY [RecyclerID]) AS [ROW]
			FROM [dbo].[Recycler] WHERE [CardboardandPaper]=1
		) AS temp
		GROUP BY [ROW], [RecyclerID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END
	ELSE IF(@waste = 'Plastic')
	BEGIN 
		SELECT @dest=[RecyclerID] FROM (
			SELECT 
			[RecyclerID], ROW_NUMBER() OVER(ORDER BY [RecyclerID]) AS [ROW]
			FROM [dbo].[Recycler] WHERE [Plastic]=1
		) AS temp
		GROUP BY [ROW], [RecyclerID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END
	ELSE IF(@waste = 'Glass')
	BEGIN 
		SELECT @dest=[RecyclerID] FROM (
			SELECT 
			[RecyclerID], ROW_NUMBER() OVER(ORDER BY [RecyclerID]) AS [ROW]
			FROM [dbo].[Recycler] WHERE [Glass]=1
		) AS temp
		GROUP BY [ROW], [RecyclerID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END
	ELSE IF(@waste = 'Garden Waste')
	BEGIN 
		SELECT @dest=[RecyclerID] FROM (
			SELECT 
			[RecyclerID], ROW_NUMBER() OVER(ORDER BY [RecyclerID]) AS [ROW]
			FROM [dbo].[Recycler] WHERE [GardenWaste]=1
		) AS temp
		GROUP BY [ROW], [RecyclerID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END
	ELSE
	BEGIN 
		SELECT @dest=[LocationID] FROM (
			SELECT 
			[LocationID], ROW_NUMBER() OVER(ORDER BY [LocationID]) AS [ROW]
			FROM [dbo].[Landfill]
		) AS temp
		GROUP BY [ROW], [LocationID]
		HAVING [ROW]=(CONVERT(INT, RAND()*100)%MAX([ROW]) + 1);
	END;

	SELECT @dest AS [Destination];
END
GO