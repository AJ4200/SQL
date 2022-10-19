--PART 1
DROP PROCEDURE [dbo].[spProcessRequest]
DROP PROCEDURE [dbo].[spPendingRequestsFor]
DROP PROCEDURE [dbo].[spArrivedAtGardenSite]

--PART 2
CREATE PROCEDURE [dbo].[spPendingRequestsFor]
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

	SELECT [RequestNumber], [Bin], wa.[Name] AS [Waste], [RequestDate] AS [RequestedAt]
	FROM [dbo].[Request]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	WHERE [RequestNumber] IN (
		SELECT [Request]
			FROM [dbo].[Collection]
			WHERE [ArrivedAtGardenSite] IS NULL
	) 
	AND [Supervisor]=@supervisor

END
GO

CREATE PROCEDURE [dbo].[spProcessRequest]
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

	DECLARE @output TABLE (ID UNIQUEIDENTIFIER, RequestDate DATETIME, Bin CHAR(8), Waste NVARCHAR(50), GardenSite CHAR(5), 
			Supervisor CHAR(6));
	
	DECLARE @dequeuedtruck TABLE (ID UNIQUEIDENTIFIER, Truck CHAR(3));
	DECLARE @truck CHAR(3);
	DECLARE @driver CHAR(6);
	DECLARE @request INT;

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

		INSERT INTO [dbo].[Collection] (Truck, Driver, Landfill, Request)
		VALUES (@truck, @driver, 'LF627', @request)
	END

END
GO

CREATE PROCEDURE [dbo].[spArrivedAtGardenSite]
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

	UPDATE [dbo].[Truck]
	SET [Bin]=@gsBin
	WHERE [Bin]=@trBin

END
GO

--PART 3
EXEC [dbo].[spEnqueueTruck] 'STF501';
EXEC [dbo].[spEnqueueTruck] 'STF502';
EXEC [dbo].[spEnqueueTruck] 'STF503';
EXEC [dbo].[spEnqueueTruck] 'STF504';
EXEC [dbo].[spEnqueueTruck] 'STF505';
EXEC [dbo].[spEnqueueTruck] 'STF506';
EXEC [dbo].[spEnqueueTruck] 'STF507';
EXEC [dbo].[spEnqueueTruck] 'STF508';
EXEC [dbo].[spEnqueueTruck] 'STF509';
EXEC [dbo].[spEnqueueTruck] 'STF510';
EXEC [dbo].[spEnqueueTruck] 'STF511';
EXEC [dbo].[spEnqueueTruck] 'STF502';
EXEC [dbo].[spEnqueueTruck] 'STF513';
EXEC [dbo].[spEnqueueTruck] 'STF514';
EXEC [dbo].[spEnqueueTruck] 'STF515';
EXEC [dbo].[spEnqueueTruck] 'STF516';
EXEC [dbo].[spEnqueueTruck] 'STF517';
EXEC [dbo].[spEnqueueTruck] 'STF518';
EXEC [dbo].[spEnqueueTruck] 'STF519';
EXEC [dbo].[spEnqueueTruck] 'STF520';

--PART 4
EXEC [dbo].[spRequestCollection] 'BIN13001', 'General Waste', 'GS306', 'STF106'
EXEC [dbo].[spRequestCollection] 'BIN13222', 'Plastic', 'GS302', 'STF102'
EXEC [dbo].[spRequestCollection] 'BIN16108', 'Garden Waste', 'GS306', 'STF106'
EXEC [dbo].[spRequestCollection] 'BIN16291', 'General Waste', 'GS303', 'STF103'
EXEC [dbo].[spRequestCollection] 'BIN17540', 'Industrial Waste', 'GS305', 'STF105'
EXEC [dbo].[spRequestCollection] 'BIN17596', 'General Waste', 'GS304', 'STF104'
EXEC [dbo].[spRequestCollection] 'BIN18149', 'Garden Waste', 'GS305', 'STF105'
EXEC [dbo].[spRequestCollection] 'BIN23207', 'Industrial Waste', 'GS301', 'STF101'
EXEC [dbo].[spRequestCollection] 'BIN24451', 'Industrial Waste', 'GS302', 'STF102'
EXEC [dbo].[spRequestCollection] 'BIN24716', 'General Waste', 'GS301', 'STF101'
EXEC [dbo].[spRequestCollection] 'BIN25053', 'Industrial Waste', 'GS303', 'STF102'
EXEC [dbo].[spRequestCollection] 'BIN29165', 'Garden Waste', 'GS305', 'STF105'