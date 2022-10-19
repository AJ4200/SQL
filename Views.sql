--Views for Staff
CREATE OR ALTER VIEW [dbo].[Driver] AS
	SELECT [StaffID], [Name], [Surname], [Email], [Telephone], [LicenceNumber]
	FROM [dbo].[Staff]
	WHERE [dtype]='Driver' AND [Active]=1;
GO

CREATE OR ALTER VIEW [dbo].[Admin] AS
	SELECT [StaffID], [Name], [Surname], [Email], [Telephone]
	FROM [dbo].[Staff]
	WHERE [dtype]='Admin' AND [Active]=1;
GO

CREATE OR ALTER VIEW [dbo].[Supervisor] AS
	SELECT [StaffID], [Name], [Surname], [Email], [Telephone]
	FROM [dbo].[Staff]
	WHERE [dtype]='Supervisor' AND [Active]=1;
Go

--Views for Locations
CREATE OR ALTER VIEW [dbo].[ControlStation] AS
	SELECT [LocationID], [Address]
	FROM [dbo].[Location]
	WHERE [dtype]='Control Station'  AND [Active]=1;
GO

CREATE OR ALTER VIEW [dbo].[Landfill] AS
	SELECT [LocationID], [Address]
	FROM [dbo].[Location]
	WHERE [dtype]='Landfill' AND [Active]=1;
GO

CREATE OR ALTER VIEW [dbo].[GardenSite] AS
	SELECT gs.[LocationID], gs.[Address], CONCAT(su.[Name], ' ', su.[Surname]) AS [Supervisor]
	FROM [dbo].[Location] gs
	INNER JOIN [dbo].[Staff] su ON [Supervisor]=su.[StaffID]
	WHERE gs.[dtype]='Garden Site' AND gs.[Active]=1;
Go

--View for Bins
CREATE OR ALTER VIEW [dbo].[BinView] AS
	SELECT [BinID] AS [Bin], w.[Name] AS [Waste]
	FROM [dbo].[Bin]
	LEFT JOIN [dbo].[Waste] w ON w.[WasteNumber]=[Waste]
	WHERE [Active]=1;
Go

--View for Trucks
CREATE OR ALTER VIEW [dbo].[TruckView] AS
	SELECT tr.[TruckID], tr.[NumberPlate], [Bin],
		CONCAT(dr.[Name], ' ', dr.[Surname]) AS [Driver]
	FROM [dbo].[Truck] tr
	INNER JOIN [dbo].[Staff] dr ON tr.[Driver]=dr.[StaffID]
	WHERE tr.[Active]=1;
Go

--View for Collection and Request
CREATE OR ALTER VIEW [dbo].[CollectionLog] AS
	SELECT req.[Bin], wa.[Name] AS [Waste], tr.[NumberPlate] AS [Truck],
		CONCAT(dr.[Name], ' ', dr.[Surname]) AS [Driver], 
		CONCAT(su.[Name], ' ', su.[Surname]) AS [Supervisor],
		lf.[Address] AS [SentTo],
		[Recycled], gs.[Address] AS [GardenSite],
		[RequestNumber], [RequestDate] AS [RequestDate],
		[CollectionNumber], [ArrivedAtControlStation] AS [CollectionDate]
	FROM [dbo].[Collection] col 
	INNER JOIN [dbo].[Request] req ON col.[Request] = req.[RequestNumber]
	INNER JOIN [dbo].[Staff] dr ON [Driver]=dr.[StaffID]
	INNER JOIN [dbo].[Staff] su ON [Supervisor]=su.[StaffID]
	INNER JOIN [dbo].[Truck] tr ON [Truck]=tr.[TruckID]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	INNER JOIN [dbo].[Location] gs ON [GardenSite]=gs.[LocationID]
	Left JOIN [dbo].[Location] lf ON [Destination]=lf.[LocationID]
	WHERE [ArrivedAtLandfill] IS NOT NULL;
GO

CREATE OR ALTER VIEW [dbo].[RequestLog] AS
	SELECT [RequestNumber], req.[Bin], wa.[Name] AS [Waste], gs.[Address] AS [GardenSite],
		CONCAT(su.[Name], ' ', su.[Surname]) AS [Supervisor], [RequestDate], [Received]
	FROM [dbo].[Request] req
	INNER JOIN [dbo].[Staff] su ON [Supervisor]=su.[StaffID]
	INNER JOIN [dbo].[Waste] wa ON [Waste]=wa.[WasteNumber]
	INNER JOIN [dbo].[Location] gs ON [GardenSite]=gs.[LocationID];
GO