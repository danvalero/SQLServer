-- Usa WWI_for_ss2.bak

--------- Limpieza

USE [WideWorldImporters]
GO
DROP INDEX [ix_test] ON [Sales].[OrderLines]
GO
DROP STATISTICS [Sales].[OrderLines].[TotalStatsFullScan]
GO
DROP STATISTICS [Sales].[OrderLines].[filteredstatslsat2months]
GO
ALTER TABLE [Sales].[OrderLines] DROP COLUMN [totalforline]
GO

--------------

SELECT * 
FROM Sales.OrderLines
WHERE OrderID IN ( 242,11064)

-- 5 para 242 y 1 para 11064

----

SELECT OrderId, SUM(quantity*UnitPrice) as salesTotal
FROM Sales.OrderLines
group by OrderID 

-- total de registros en la tabla 

SELECT OrderId, SUM(quantity*UnitPrice) as salesTotal
FROM Sales.OrderLines
WHERE OrderID = 242 or OrderID = 500
group by OrderID 


--
SELECT * 
FROM Sales.OrderLines
WHERE OrderID = 1


SELECT * 
FROM Sales.OrderLines
WHERE abs(OrderID) = 1 

-- SELECT 231412 * 1.358788E-05
-- total de registros * densidad

SELECT * 
FROM Sales.OrderLines
WHERE abs(OrderID) = -1

-- mismo resultado

SELECT * 
FROM Sales.OrderLines
WHERE quantity*UnitPrice = 100

SELECT * 
FROM Sales.OrderLines
WHERE quantity*UnitPrice > 100

--SELECT 231412 * .3

-- ?como podemos ayudar al optimizador?

ALTER TABLE Sales.OrderLines 
ADD [totalforline]  AS ([UnitPrice]*[Quantity])

CREATE STATISTICS TotalStatsFullScan 
ON Sales.OrderLines (totalforline) WITH FULLSCAN;

dbcc show_statistics ('Sales.OrderLines',TotalStatsFullScan)

SELECT * 
FROM Sales.OrderLines
WHERE quantity*UnitPrice = 100

SELECT * 
FROM Sales.OrderLines
WHERE totalforline = 100

SELECT * 
FROM Sales.OrderLines
WHERE quantity*UnitPrice > 100

SELECT * 
FROM Sales.OrderLines
WHERE totalforline > 100

create index ix_test
on Sales.OrderLines (totalforline)

SELECT * 
FROM Sales.OrderLines
WHERE quantity*UnitPrice = 100

SELECT * 
FROM Sales.OrderLines
WHERE totalforline = 100


-- estadisticas filtradas

SELECT MIN(PickingCompletedWhen), 
	   MAX(PickingCompletedWhen) 
FROM Sales.OrderLines 

SELECT * 
FROM Sales.OrderLines
WHERE PickingCompletedWhen = '2016-05-15'
-- Estima 199.75

dbcc show_statistics ('Sales.OrderLines',[IX_Sales_OrderLines_Perf_20160301_01])

-- ?como podemos ayudar al optimizador?

CREATE STATISTICS filteredstatslsat2months
ON Sales.OrderLines (PickingCompletedWhen) 
WHERE PickingCompletedWhen >= '2016-04-01'
with fullscan 

dbcc freeproccache

SELECT * 
FROM Sales.OrderLines
WHERE PickingCompletedWhen = '2016-05-15'


dbcc show_statistics ('Sales.OrderLines',[filteredstatslsat2months])

So, how are the Density Vector and Histogram used in Cardinality Estimation?
Density Vector
GROUP BY
Local Variable
Multi-column

Histogram
RANGE_HI_KEY
AVG_RANGE_ROWS
Inequality operator
Filtered

-- probar ascending key

SELECT * 
FROM Sales.OrderLines
WHERE OrderID = 5939  and  PackageTypeID = 7

SELECT * 
FROM Sales.OrderLines
WHERE OrderID = 5939  and  PackageTypeID = 7
OPTION (USE HINT ( 'FORCE_LEGACY_CARDINALITY_ESTIMATION' ))

--------------------------------------------------------------------------------------
-- VER ESTADISTICAS USADAS 

alter database [WideWorldImporters] SET compatibility_level = 110;

use WideWorldImporters

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS 

SELECT * 
FROM Sales.OrderLines
WHERE OrderID = 2423
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

SELECT * FROM sys.stats WHERE object_id = OBJECT_ID('Sales.OrderLines')

sp_helpindex 'Sales.OrderLines'
go

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS 

SELECT * 
FROM Sales.OrderLines
WHERE StockItemID = 95 and PickingCompletedWhen = '2015-02-12 11:00:00.000'
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 9292,
    QUERYTRACEON 9204
)

SELECT * FROM sys.stats WHERE object_id = OBJECT_ID('Sales.OrderLines')

sp_helpindex 'Sales.OrderLines'
go

alter database [WideWorldImporters] SET compatibility_level = 130;

------------------------------

SELECT * 
FROM Sales.OrderLines
WHERE OrderID = 242
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 2363
)

--Loaded histogram 

SELECT * FROM sys.stats WHERE object_id = OBJECT_ID('Sales.OrderLines')

dbcc show_statistics ('Sales.OrderLines',FK_Sales_OrderLines_OrderID)

-- SELECTivity para OrderId
SELECT cast(5 as float)/ cast(231412 as float) 


DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS 

SELECT * 
FROM Sales.OrderLines
WHERE StockItemID = 95 and PickingCompletedWhen = '2015-02-12 11:00:00.000'
OPTION
(
    QUERYTRACEON 3604,
    QUERYTRACEON 2363
)
