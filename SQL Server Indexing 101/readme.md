# SQL Server Indexing 101

- [1. Setting up the environment](#1-setting-up-the-environment)
- [2. Basic indexing 1 (searching conditions on a single column)](#2-basic-indexing-1-searching-conditions-on-a-single-column)
- [3. Basic indexing 2 (searching conditions on multiple column)](#3-basic-indexing-2-searching-conditions-on-multiple-column)
- [4. Order of columns and logical operators used to combine conditions and the impact on the index usage](#4-order-of-columns-and-logical-operators-used-to-combine-conditions-and-the-impact-on-the-index-usage)
- [5. Redundant indexes](#5-redundant-indexes)
- [6. Why is SQL Server not using existing indexes?](#6-why-is-sql-server-not-using-existing-indexes)

I will go step by step in the process of indexing a table to improve query performance. For this scenario, we will focus on reducing the number of pages read by the query as the criteria for success.

## 1. Setting up the environment

If you want to do the demos by yourself, I recommend you to:

1. Install SQL Server 2019 Developer Edition from [SQL Server Downloads](https://www.microsoft.com/es-mx/sql-server/sql-server-downloads)

1. Restore AdventureWorks2019 OLTP sample database available at [AdventureWorks sample databases](https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=ssms)

1. Make some changes so the demos work correctly.

   ```sql
	USE [AdventureWorks2019]
	GO
	DROP TABLE IF EXISTS Person.PersonDemo
	GO
	UPDATE [Sales].[SalesOrderHeader]
	SET [ShipDate] = null, [Status] = 3
	WHERE TerritoryID = 1 and SalesPersonID = 281
	GO
	DROP INDEX [IX_SalesOrderHeader_CustomerID] ON [Sales].[SalesOrderHeader]
	GO
	```

---

## 2. Basic indexing 1 (searching conditions on a single column)

1. Open a new query window

1. Create a sample table with no clustered index

	```sql
	SELECT * 
	INTO Person.PersonDemo
	FROM Person.Person
	```

1. Tell SQL Server to display information about the amount of disk activity generated by Transact-SQL statements.

	```sql
	SET statistics io ON
	```

1. Enable **Include Actual Execution Plan** by pression Ctrl+M

1. Query the table Person.PersonDemo

	```sql
	SELECT * FROM Person.PersonDemo
	```

	Go to the *Execution Plan* tab. Notice the plan uses a **Table Scan** operator.

	![](Media/table-scan-1.PNG)

	This is expected as there is no index on the table and the query does not have a WHERE clause.

	Go to the *Messages* tab. Notice the total of logical reads, it is about 3809 

	![](Media/table-scan-reads-1.PNG)

1. Create a Clustered Index on Person.PersonDemo and execute the same query

	Create the clustered index by executing:
	
	```sql
	ALTER TABLE Person.PersonDemo
	ADD CONSTRAINT PK_PersonDemo_BusinessEntityID
	PRIMARY KEY CLUSTERED (BusinessEntityID);
	GO
	```

	Execute the same query executed in the previous step

	```sql
	SELECT * FROM Person.PersonDemo
	GO
	```

	Go to the *Execution Plan* tab. Notice the plan uses a **Clustered Index Scan** operator.

	![](Media/clustered-index-scan-1.PNG)

	You migth think this is a better execution plan. Is this really a better plan?

	Go to the *Messages* tab. Notice the total of logical reads, it is about 3818. This query actually did more logical reads 

	![](Media/clustered-index-scan-reads-1.PNG)

	Q: Why the plan that uses **Clustered Index Scan** does more loginal reads than the plan that uses a **Table Scan**?
	A: The Clustered Index is the table physicaily order by the index key, The table with no clusterd index (called a HEAP) is the table with no order for the rows. As the Cluster Index is a BTree strcuture, it has more pages than the HEAP. For this reason the **Clustered Index Scan** does more reads than the **Table Scan**

1. Find a row by using a simple equality condition on the key of the Clustered Index

	```sql
	SELECT *
	FROM Person.PersonDemo
	WHERE BusinessEntityID = 20774
	```

	Go to the *Execution Plan* tab. Notice the plan uses a **Clustered Index Seek** operator.

	![](Media/clustered-index-seek-1.PNG)

	Go to the *Messages* tab. Notice the total of logical reads, it is about 3. This query was very efficient. This expeted beacuse you are looking for a unique row using the clustered index key.

	![](Media/clustered-index-seek-reads-1-1.PNG)

1. Find a row by using a simple equality condition on a non indexed column  

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE FirstName = 'Omar'
	```

	Go to the *Execution Plan* tab. Notice the plan uses a **Clustered Index Scan** operator.

	![](Media/clustered-index-scan-2.PNG)

	You migth this is a good plan because you are using the Clustered Index, however, remember that the Clustered Index is just  the table physically order by the index key, so the query is reading all rows in the table

	Go to the *Messages* tab. Notice the total of logical reads, it is about 3818. 

	![](Media/clustered-index-scan-reads-2.PNG)

	Q: Can you think of a way to reduce the logical reads and improve the overall performance of the query?

	Create an non clustered index on column **FirstName**

	```sql
	CREATE NONCLUSTERED INDEX [ix_PersonDemo_FirstName] 
	ON [Person].[PersonDemo] ([FirstName] ASC)
	```

	Execute the query again

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE FirstName = 'Omar'
	```

	Go to the *Execution Plan* tab. Notice the plan uses an **Index Seek** and a **Key Lookup** operator.

	* The Index Seek operator was used to locate all rows where *FirstName='Omar'*
	* The Key Lookup  operator was used to retrieve the actual rows where *FirstName='Omar'*. It is executed, by SQL Server, after the Index Seek operation.

	![](Media/Index-seek-and-lookup-1.PNG)

	Go to the *Messages* tab. Notice the total of logical reads, it is about 135, a big reduction compared to the pages reads when Clustered Index Scan operator was used. 

	![](Media/Index-seek-and-lookup-reads-1.PNG)

1. Let's see what happen when a wildcard is used in the search value

	Let's retrieve all rows where the value on FirstName ends with *mar*. Execute:

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE  FirstName like '%mar'
	```

	Go to the *Execution Plan* tab. Notice the plan looks similar but if you take a closer look you will notice it uses an **Index Scan** operator instead of an  **Index Seek** operator.

	![](Media/Index-scan-and-lookup-1.PNG)

	Go to the *Messages* tab. Notice the total of logical reads, it is about 210. The number of reads increased because you are now scaning the index to idenitify all rows where FirstName ends with *mar*, it is better than doing a **Clustered IndexScan** but not as good as doing an **Index Seek**

	**IMPORTANT:** I am not saying than using wildcard at the end of the search value is bad and you shuold never do it, just undestand the impact of doing it and try to avoid it if possible.

	Let's retrieve all rows where the value on FirtName starts with *Om*. Execute:

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE  FirstName like 'Om%'
	```

	Notice the plan uses an **Index Seek** and a **Key Lookup** operator.

	![](Media/Index-seek-and-lookup-2.PNG)

	Go to the *Messages* tab. Notice the total of logical reads, it is about 146. The number of reads reduced but it is still higher than the query that does not use wildcards, it is normal becuase you are not looking for an specific value, but a range of values.

---

## 3. Basic indexing 2 (searching conditions on multiple column)

Find a row by using equality conditions on two different columns

```sql
SELECT * 
FROM Person.PersonDemo
WHERE  FirstName = 'Omar' 
	and LastName = 'Jai' 
```

Go to the *Execution Plan* tab.  Notice the plan uses an **Index Seek** and a **Key Lookup** operator.

It seems to be a good plan, it uses an efficient **Index Seek** operator

Go to the *Messages* tab. Notice the total of logical reads, it is about 135. This is what we saw when the WHERE clause only had a condition on the LastName column.

The plan seems to be very good and uses an efficient operator.

Q: Can you think of a way of making this index more efficient
Hint: There are two possible ways to do it.

1. Create an index on the column *LastName*

	```sql
	CREATE NONCLUSTERED INDEX [ix_PersonDemo_LastName] 
	ON [Person].[PersonDemo] ([LastName] ASC )
	```

	Execute the query again

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE  FirstName = 'Omar' 
		and LastName = 'Jai' 
	```

	Go to the *Execution Plan* tab. The plan seems to be more complex and it uses two **Index Seek** operators and a **Merge Join** operator:
		- SQL Server does an Index Seek to identify all rows where FirstName='Omar'
		- Then it does an Index Seek to identify all rows where LastName='Jai'
		- Later, it does a Merge Join to have get rows where FirstName='Omar' and LastName='Jai' with no duplicated values.
		- Finally, it does a key look up to retrieve all columns for all rows that complies with both conditions.

	![](Media/query-two-columns-1.PNG)

	Q: Was the index helpfulp?

	Go to the *Messages* tab. Notice the total of logical reads, it is about 8. Using both indexes helped reduce the reads required to execute the query. 

	![](Media/query-two-columns-reads-1.PNG)

1. Create a composite index on FirstName and LastName:

	```sql
	CREATE NONCLUSTERED INDEX [ix_PersonDemo_FirstName_LastName] 
	ON [Person].[PersonDemo] ([FirstName] ASC, [LastName] ASC)
	```

	Execute the query again

	```sql
	SELECT * 
	FROM Person.PersonDemo
	WHERE  FirstName = 'Omar' 
		and LastName = 'Jai' 
	```

	Go to the *Execution Plan* tab.  Notice the plan uses an **Index Seek** on the **ix_PersonDemo_FirstName_LastName** index

	![](Media/Index-seek-and-lookup-2.PNG)

	Q: Is this better than using both ix_PersonDemo_FirstName and ix_PersonDemo_LastName indexes?

	Go to the *Messages* tab. Notice the total of logical reads, it is about 5. Using the composite index requires to do less reads. This could be the best option.

---

## 4. Order of columns and logical operators used to combine conditions and the impact on the index usage

The index *ix_PersonDemo_FirstName_LastName* was created on columns FirstName and LastName (in that specific order)

Q: Will the idex be used if the columns are used in a different order in the WHERE clause?

Execute (at the same time) two queries that return the same result but the WHERE clause as written diffrently (the order of the columns in the condition was inverted)

```sql
SELECT * 
FROM Person.PersonDemo
WHERE  FirstName = 'Omar' 
	and LastName = 'Jai' 

SELECT * 
FROM Person.PersonDemo
WHERE LastName = 'Jai' 
	and FirstName = 'Omar' 
```

Go to the *Execution Plan* tab. Notice both queries use the same plan, and the plan does an Index Seek on ix_PersonDemo_FirstName_LastName

![](Media/query-column-order-1.PNG)

SQL Server internally rewrites the query in such a way that the index can be used no matter the order of the columns in the where clause. This works because both conditions are used with the AND logical operator.

Replace the AND logical operator with an OR logical operator. You get a completely different query. Execute:

```sql
SELECT * 
FROM Person.PersonDemo
WHERE FirstName = 'Omar' 
	  OR
	  LastName = 'Jai'
```

Go to the *Execution Plan* tab. The plan does:
- an Index Seek on *ix_PersonDemo_FirstName_LastName* to identify all rows where FirstName='Omar'
- an Index Seek on *ix_PersonDemo_LastName* to identify all rows where LastName='Jai'
- a concatenation to join all rows where FirstName = 'Omar' and LastName='Jai'  
- a sort to delete duplicated rows

![](Media/query-condition-or-1.PNG)

From the plan it is safe to say that it is not the same to combine conditions  using the AND logical operator than to combine conditions using the OR logical operator, and in consequence different indexes might be required.

---

## 5. Redundant indexes

At this point, the table *PersonDemo* has 3 indexes:

- ix_PersonDemo_FirstName o FirstName
- ix_PersonDemo_LastName on LastName
- ix_PersonDemo_FirstName_LastName on FirstName and LastName

Some concern arise now:

- *ix_PersonDemo_FirstName* is redundant with *ix_PersonDemo_FirstName_LastName*, which one should be deleted?
If your queries will search on FirstName and LastName, delete *ix_PersonDemo_FirstName*. If your queries only search on FirstName delete *ix_PersonDemo_FirstName_LastName*
- Should you delete *ix_PersonDemo_LastName*?
If you have other queries that search only by LastName or the search condition on LastName is combined with other conditions using an OR logical operator, you could  need it.

For demo purposes, drop *ix_PersonDemo_FirstName*

```sql
DROP INDEX [ix_PersonDemo_LastName] ON [Person].[PersonDemo]
```

List all indexes on the table and confirm there are no duplicated or redundant indexes 
```sql
sp_helpindex 'Person.PersonDemo'
```

## 6. Why is SQL Server not using existing indexes?

Some common causes for SQL Server not to use (or not used as we expect) an existing index, and what we can do about it.

### Reason 1: The tipping point

Open a new query window

Tell SQL Server to display information about the amount of disk activity generated by Transact-SQL statements:
```sql
SET STATISTICS IO ON
```

Enable **Include Actual Execution Plan** by pressing Ctrl+M

Execute a simple query
```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'SC'
```

Go to the *Execution Plan* tab. Notice the plan uses a **Clustered Index Scan** operator. It makes sense, there is no index on PersonType

Create a non clustered index on column **PersonType**
```sql
CREATE NONCLUSTERED INDEX [ix_PersonDemo_PersonType] 
ON [Person].[PersonDemo] ([PersonType] ASC )
```

Execute the same query again
```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'SC' 
```
Go to the *Execution Plan* tab. Notice the plan does an **Index Seek** on *ix_PersonDemo_PersonType*. This is what we were looking for when created the index

![](Media/tipping-point-1.PNG)

Execute the same query but look for another value of PersonType
```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'VC'
```

Go to the *Execution Plan* tab. Nothing unexpected, the index *ix_PersonDemo_PersonType* is being used

Execute the same query but look for two different values of PersonType

```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'SC' OR PersonType = 'VC'
```

Go to the *Execution Plan* tab. Nothing unexpected, the index *ix_PersonDemo_PersonType* is being used

Execute the same query but look for other value of PersonType
```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'IN'
```

Go to the *Execution Plan* tab. The plan is now doing a **Clustered Index Scan**, that means it is scanning all rows on the table instead of using the index. 

![](Media/tipping-point-2.PNG)

What happened? Has SQL Server gone crazy? There is an index for PersonType, and it used it before, why is it not using it now?

Count how many rows there are for each value of PersonType
```sql
SELECT PersonType, count(*) NumerOfRows
FROM Person.PersonDemo
GROUP BY PersonType
ORDER BY 2 DESC
```

![](Media/tipping-point-3.PNG)

Notice that there are few rows for *SP*, *VC*, etc, but many rows for *IN*. In this case SQL Server has determined that using an **Index Seek** operation to get rows where PersonType='IN' is more expensive than doing a **Clustered Index Scan**

Let's see in more detail the execution plans to find out why SQL Server is making such a decision.

Execute again the query
```sql
SELECT * 
FROM Person.PersonDemo
WHERE PersonType = 'IN'
```

Go to the *Execution Plan* tab. 

Put the mouse over the arrow that goes from the **Clustered Index Scan** operator to the **SELECT** operator

![](Media/tipping-point-4.PNG)

Notice SQL Server estimated that it would return 18424 and it actually read 18424 rows.

Put the mouse over the **SELECT** operator

![](Media/tipping-point-5.PNG)

Notice the estimated cost of the query is 2.84525

Go to the *Messages* tab. Notice the total of logical reads, it is about 3818.

![](Media/tipping-point-6.PNG)

Lets assume for a moment that SQL Server is doing a bad job and it is not using *ix_PersonDemo_PersonType* for some strange unknown reason, so execute the query forcing the index

```sql
SELECT * 
FROM Person.PersonDemo WITH (INDEX(ix_PersonDemo_PersonType))
WHERE PersonType = 'IN'
```
Go to the *Execution Plan* tab. 

![](Media/tipping-point-7.PNG)

It now uses an Index Seek. But, is that really better?

Put the mouse over the **SELECT** operator

![](Media/tipping-point-8.PNG)

Notice the estimated cost of the query is 14.8537. This plan is seven times more expensive than the plan that does a **Clustered Index Scan** 

Go to the *Messages* tab. 

![](Media/tipping-point-9.PNG)

Notice the total of logical reads, it is about 57246, almost 15 times more reads that the plan that does a **Clustered Index Scan** 

SQL Server had already evaluated the cost of using an **Index Seek** and the cost of using an **Clustered Index Scan** and chose the best of both options

**IMPORTANT:** This is a simple example and SQL Server was able to choose the best execution plan, but in more complex scenarios SQL Server will look for a good enough plan, not necessarily the best plan

Q: SQL Server does a good job when creating the execution plan, does it means that I should never force indexes?

A: No, query hints are useful in some scenarios, just make sure you are using them correctly. Compare the plan with and without the hint and select the best option depending on the results.

Ok, so what is the **Tipping Point** then? it is the point at which the number of page reads required by the lookups operator are higher than the total number of data pages in the table. If this happens doing an Index Seek is more expensive than scanning the table 

In the previous example, SQL Server decided to use or not use an index depending on the number of estimated rows to be returned. How did SQL Server know how many  rows the query would return? The answer is simple: **statistics**

Statistics is complex topic that will be covered in another post, but I will introduce the concept here to complete the explanation of the tipping point.

Review the statistics for the *ix_PersonDemo_PersonType* index by executing:

```sql
DBCC SHOW_STATISTICS ('Person.PersonDemo',ix_PersonDemo_PersonType)
```

![](Media/tipping-point-10.PNG)

In the third part of the output, you have the histogram. Notice that SQL Server knows how many rows there are for each value of *PersonType*. In this example, you have accurate values, however, if the first column of the index key has many different values or there were many updates on the table since the last time the statistics was updated the values on the histogram will not be exact, but this a topic for another post. 

When SQL Server is creating the execution plan for a query it identify relevant indexes and uses the statistics to determine the expected number of rows to be read for an operator and decide the best way to access the data.

The Execution Plan XML has a property named **OptimizerStatsUsage** that lists all statistics that were used during the optimization of the execution plan. You can also see the proprerty in SSMS

![](Media/tipping-point-11.PNG)

---

### Reason 2: Non Sargable expresions

Some constructions can make SQL Server unable to use an existing index on an **Index Seek** or **Clustered Index Seek** operation, causing the usage of **Index Scan** or a **Clustered Index Scan** operator.

One common reason for an expression to be non sargable is the usage of functions

#### A.  Usage of explicit functions 

Create a non clustered index on [ModifiedDate] 

```sql
CREATE NONCLUSTERED INDEX [ix_PersonDemo_ModifiedDate] 
ON [Person].[PersonDemo] ([ModifiedDate] ASC )
```

Get the rows for a specific month

```sql
SELECT * 
FROM Person.PersonDemo
WHERE YEAR(ModifiedDate) = 2009
	  and 
	  MONTH(ModifiedDate) = 02
```

Go to the *Execution Plan* tab. You might expect SQL Server to do an **Index Seek** on *ix_PersonDemo_ModifiedDate*, however, it is using an **Index Scan**

![](Media/nonsargable-1.PNG)

Even when there is an index on *ModifiedDate*, in the WHERE clause the search condition uses a function on *ModifiedDate*. The index is on *ModifiedDate*, not YEAR(ModifiedDate) or YEAR(ModifiedDate), so SQL Server has no option other than scanning the index.

This is a common pattern, but it can be easily fixed. The query can be rewritten as

```sql
SELECT * 
FROM Person.PersonDemo
WHERE ModifiedDate >= '2009-02-01'
	  AND 
	  ModifiedDate < '2009-03-01'
```

Execute the query and go to the *Execution Plan* tab. Now the plan uses a **Index Seek** on *ix_PersonDemo_ModifiedDate*

![](Media/nonsargable-2.PNG)

As another example execute

```sql
SELECT * 
FROM Person.PersonDemo
WHERE FirstName = 'Omar'
```

Go to the *Execution Plan* tab. You might expect SQL Server to do an **Index Seek** on *ix_PersonDemo_FirstName_LastName*

![](Media/nonsargable-3.PNG)

Now execute

```sql
SELECT * 
FROM Person.PersonDemo
WHERE UPPER(FirstName) = UPPER('Omar')
```

Notice that in this case it returns the exact same information as the query that does not use the UPPER function.

Go to the *Execution Plan* tab. Notice that is now uses an **Index Scan** on *ix_PersonDemo_FirstName_LastName*

![](Media/nonsargable-4.PNG)

The reason, the usage of the function UPPER on the search column

The solution for this case will depend on the real scenario, but in general, there are two option:
- If your database/table/column is case sensitive, clean up data and make sure data is inserted using the expected case so the query can be written without UPPER.
- If your database/table/column is not case sensitive, there is no need to use UPPER, so it can be removed from the query

#### B. Implicit conversions 

This a special case of function usage

Execute:
```sql
SELECT *
FROM [HumanResources].[Employee]
WHERE NationalIDNumber = 301435199
```

Go to the *Execution Plan* tab. A **Clustered Index Scan** is used even when there is an index on *NationalIDNumber*

![](Media/nonsargable-5.PNG)

In this case, the column name *NationalIDNumber* seems to indicate that the column represents a numeric value, however, if you check the data type for the column 

```sql
SELECT name column_name, TYPE_NAME (system_type_id) data_type 
FROM sys.columns C
WHERE object_id = OBJECT_ID('HumanResources.Employee')
	  AND
	  name = 'NationalIDNumber'
```

You will see the data type for *NationalIDNumber* is *varchar*.

In this case, SQL Server is doing an implicit conversion (applying a function on *NationalIDNumber*) causing the use of the **Clustered Index Scan**

If the query is modified to use the correct data type for the search value

```sql
SELECT *
FROM [HumanResources].[Employee]
WHERE NationalIDNumber = '301435199'
```

the execution plan uses an **Index Seek**

![](Media/nonsargable-6.PNG)

