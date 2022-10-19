CREATE TABLE [dbo].[Staff] (
	[dtype]		NVARCHAR(15)	NOT NULL,
    [StaffID]	CHAR(6)		NOT NULL,
	[IdNumber]	CHAR(13)		NOT NULL,
	[Name]		NVARCHAR(50)	NOT NULL,
	[Surname]	NVARCHAR(50)	NOT NULL,
	[Email]		NVARCHAR(100)	NOT NULL,
	[Password]	NVARCHAR(MAX)	NOT NULL,
	[Telephone]	NVARCHAR(10)	NOT NULL,
	[LicenceNumber]	CHAR(12)	NULL,
	[Active] 		BIT 		NOT NULL DEFAULT 1,
    PRIMARY KEY CLUSTERED ([StaffID] ASC),
	CONSTRAINT [CK_StaffType] CHECK ([dtype] in ('Driver','Admin','Supervisor'))
)

CREATE TABLE [dbo].[Location] (
	[dtype]			NVARCHAR(20)		NOT NULL,
	[Address]		NVARCHAR(150)		NOT NULL,
    [LocationID]	CHAR(5)		NOT NULL,
	[Longitude]		NVARCHAR(50)		NOT NULL,
	[Latitude]		NVARCHAR(50)		NOT NULL,
	[Supervisor]	CHAR(6)		NULL,
	[Active] 		BIT 		NOT NULL DEFAULT 1,
    PRIMARY KEY CLUSTERED ([LocationID] ASC),
    FOREIGN KEY ([Supervisor]) REFERENCES [dbo].Staff ([StaffID]),
	CONSTRAINT [CK_LocType] CHECK ([dtype] in ('Control Station','Landfill','Garden Site','Recycling Station'))
)

CREATE TABLE [dbo].[Waste] (
	[WasteNumber]	INT IDENTITY(1,1)	NOT NULL,
	[Name]			NVARCHAR(50)		NOT NULL,
	[Weight]		DECIMAL(18,5)		NOT NULL,
    PRIMARY KEY CLUSTERED ([WasteNumber] ASC)
)

CREATE TABLE [dbo].[Bin] (
	[BinID]		CHAR(8)			NOT NULL,
	[QRCode]	VARBINARY(MAX)	NOT NULL,
	[Waste]		INT				NOT NULL,
	[Active] 	BIT		 		NOT NULL DEFAULT 1,
    PRIMARY KEY CLUSTERED ([BinID] ASC)
)

CREATE TABLE [dbo].[BinSlot] (
	[SlotID] UNIQUEIDENTIFIER	NOT NULL,
	[Bin]			CHAR(8)		NULL,
	[GardenSite]	CHAR(5)		NOT NULL,
    PRIMARY KEY CLUSTERED ([SlotID] ASC),
    FOREIGN KEY (Bin) REFERENCES [dbo].Bin (BinID),
    FOREIGN KEY (GardenSite) REFERENCES [dbo].Location (LocationID)
)

CREATE TABLE [dbo].[Truck] (
	[TruckID]		CHAR(3)		NOT NULL,
	[NumberPlate]	NVARCHAR(10)NOT NULL,
	[Bin]			CHAR(8)		NULL,
	[Driver]		CHAR(6)		NOT NULL,
	[Active] 		BIT 		NOT NULL DEFAULT 1,
    PRIMARY KEY CLUSTERED (TruckID ASC),
    FOREIGN KEY (Bin) REFERENCES [dbo].Bin (BinID),
    FOREIGN KEY (Driver) REFERENCES [dbo].Staff (StaffID)
)

CREATE TABLE [dbo].[Request] (
	[RequestNumber]	INT IDENTITY(1,1)	NOT NULL,
	[Bin]			CHAR(8)				NOT NULL,
	[Waste]			INT					NOT NULL,
	[GardenSite]	CHAR(5)				NOT NULL,
	[Supervisor]	CHAR(6)				NOT NULL,
	[RequestDate]	DATETIME			NOT NULL,
	[Received] 		BIT 				NOT NULL DEFAULT 0,
    PRIMARY KEY CLUSTERED (RequestNumber ASC),
    FOREIGN KEY (Bin) REFERENCES [dbo].Bin (BinID),
    FOREIGN KEY (Waste) REFERENCES [dbo].Waste (WasteNumber),
    FOREIGN KEY (GardenSite) REFERENCES [dbo].Location (LocationID),
    FOREIGN KEY (Supervisor) REFERENCES [dbo].Staff (StaffID)
)

CREATE TABLE [dbo].[Collection](
	[CollectionNumber]	INT IDENTITY(1,1)	NOT NULL,
	[Truck]			CHAR(3)		NULL,
	[Driver]		CHAR(6)		NULL,
	[Destination]	CHAR(5)		NULL,
	[Request]		INT			NOT NULL,
	[ArrivedAtGardenSite]		DATETIME	NULL,
	[ArrivedAtLandfill]			DATETIME	NULL, 
	[ArrivedAtControlStation]	DATETIME	NULL,
	[Recycled]		BIT			NOT NULL DEFAULT 0,
    PRIMARY KEY CLUSTERED (CollectionNumber ASC),
    FOREIGN KEY (Truck) REFERENCES [dbo].Truck (TruckID),
    FOREIGN KEY (Driver) REFERENCES [dbo].Staff (StaffID),
    FOREIGN KEY (Destination) REFERENCES [dbo].Location (LocationID),
    FOREIGN KEY (Request) REFERENCES [dbo].Request (RequestNumber)
);

CREATE TABLE [dbo].[TruckQueue](
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL,
    ProcessingStartedAt DATETIME2,
    Truck CHAR(3),
    FOREIGN KEY (Truck) REFERENCES [dbo].Truck (TruckID)
);

CREATE TABLE [dbo].[RequestBuffer](
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL,
    ProcessingStartedAt DATETIME2,
	[Bin]			CHAR(8)				NOT NULL,
	[Waste]			INT					NOT NULL,
	[GardenSite]	CHAR(5)				NOT NULL,
	[Supervisor]	CHAR(6)				NOT NULL,
    FOREIGN KEY (Bin) REFERENCES [dbo].Bin (BinID),
    FOREIGN KEY (Waste) REFERENCES [dbo].Waste (WasteNumber),
    FOREIGN KEY (GardenSite) REFERENCES [dbo].Location (LocationID),
    FOREIGN KEY (Supervisor) REFERENCES [dbo].Staff (StaffID)
);

CREATE TABLE [dbo].[ReportBuffer](
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL,
    ProcessingStartedAt DATETIME2,
	[Request] INT		NOT NULL,
	[ArrivedAtGardenSite]		DATETIME	NULL,
    FOREIGN KEY (Request) REFERENCES [dbo].Request (RequestNumber)
);

CREATE TABLE [dbo].[Recycler](
    [RecyclerID] 		CHAR(5)		NOT NULL,
    [Name] 				NVARCHAR(50)	NOT NULL,
    [IndustrialWaste]	BIT 	NOT NULL DEFAULT 0,
    [CardboardandPaper]	BIT 	NOT NULL DEFAULT 0,
    [Plastic]			BIT 	NOT NULL DEFAULT 0,
	[Glass]				BIT 	NOT NULL DEFAULT 0,
	[GardenWaste]		BIT 	NOT NULL DEFAULT 0,
    [GeneralWaste]		BIT 	NOT NULL DEFAULT 0,
    PRIMARY KEY CLUSTERED ([RecyclerID] ASC),
	FOREIGN KEY (RecyclerID) REFERENCES [dbo].Location (LocationID)
);

CREATE TABLE [dbo].[TruckIssue](
	[Id]	UNIQUEIDENTIFIER	NOT NULL,
	[Truck]			CHAR(3)		NOT NULL,
	[Driver]		CHAR(6)		NOT NULL,
	[Request]		INT			NOT NULL,
	[ReportedAt] 	DATETIME 	NOT NULL,
	[Fixed]	 	BIT 	NOT NULL DEFAULT 0,
	[Location] 	NVARCHAR(150)	NOT NULL,
    PRIMARY KEY CLUSTERED (Id ASC),
    FOREIGN KEY (Truck) REFERENCES [dbo].Truck (TruckID),
    FOREIGN KEY (Driver) REFERENCES [dbo].Staff (StaffID),
    FOREIGN KEY (Request) REFERENCES [dbo].Request (RequestNumber)
);