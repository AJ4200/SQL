CREATE INDEX [StaffNum] ON [dbo].[Staff] ([StaffID])

CREATE INDEX [StaffAuth] ON [dbo].[Staff] ([Email])

CREATE INDEX [LocID] ON [dbo].[Location] (LocationID)

CREATE INDEX [Coordinaes] ON [dbo].[Location] ([Longitude], [Latitude])

CREATE INDEX [BinWaste] ON [dbo].[Waste] ([Name])

CREATE INDEX [QueuePop] on [dbo].[TruckQueue] (ProcessingStartedAt, CreatedAt ASC)
INCLUDE (Id)
WHERE ProcessingStartedAt IS NULL;