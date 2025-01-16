--Exploring data - 31465 Total, 27659 online (87.9%), 3806 in store (12.1%)

--Total Sales = 123216786.1159

--Final Queries
--Total sales for online and physical orders

SELECT 
    CASE 
        WHEN OnlineOrderFlag = 1 THEN 'Online Sales' 
        ELSE 'Physical Store Sales' 
    END AS SalesType,
    SUM(TotalDue) AS TotalSales
FROM 
    Sales.SalesOrderHeader
GROUP BY 
    OnlineOrderFlag
ORDER BY TotalSales DESC

--Average transaction values for online and physical stores.
SELECT 
    CASE 
        WHEN OnlineOrderFlag = 1 THEN 'Online Sales' 
        ELSE 'Physical Store Sales' 
    END AS SalesType,
    AVG(TotalDue) AS AverageTransactionValue
FROM 
    Sales.SalesOrderHeader
GROUP BY 
    OnlineOrderFlag;

--Customer Purchasing Trends - The percentage who bought online and in person
WITH CustomerCounts AS (
    SELECT 
        CASE 
            WHEN soh.OnlineOrderFlag = 1 THEN 'Online Customers' 
            ELSE 'Physical Store Customers' 
        END AS CustomerType,
        COUNT(DISTINCT soh.CustomerID) AS CustomerCount,
        COUNT(soh.SalesOrderID) AS TotalOrders
    FROM 
        Sales.SalesOrderHeader AS soh
    GROUP BY 
        soh.OnlineOrderFlag
),
TotalCounts AS (
    SELECT 
        SUM(CustomerCount) AS TotalCustomers,
        SUM(TotalOrders) AS TotalOrders
    FROM 
        CustomerCounts
)

SELECT 
    cc.CustomerType,
    cc.CustomerCount,
    (cc.CustomerCount * 100.0 / tc.TotalCustomers) AS PercentageOfCustomers,
    cc.TotalOrders,
    (cc.TotalOrders * 100.0 / tc.TotalOrders) AS PercentageOfOrders
FROM 
    CustomerCounts AS cc,
    TotalCounts AS tc;

--Product Preferences
WITH ProductSales AS (
    SELECT 
        p.ProductID,
        p.Name AS ProductName,
        CASE 
            WHEN soh.OnlineOrderFlag = 1 THEN 'Online' 
            ELSE 'Physical' 
        END AS PurchaseType,
        SUM(sod.OrderQty) AS TotalQuantity  -- Total quantity sold for each product
    FROM 
        Sales.SalesOrderHeader AS soh
    JOIN 
        Sales.SalesOrderDetail AS sod ON soh.SalesOrderID = sod.SalesOrderID
    JOIN 
        Production.Product AS p ON sod.ProductID = p.ProductID
    WHERE 
        soh.OnlineOrderFlag IS NOT NULL  -- Ensure we're considering valid orders
    GROUP BY 
        p.ProductID, 
        p.Name, 
        soh.OnlineOrderFlag
),

RankedProducts AS (
    SELECT 
        ProductID,
        ProductName,
        PurchaseType,
        TotalQuantity,
        ROW_NUMBER() OVER (PARTITION BY PurchaseType ORDER BY TotalQuantity DESC) AS ProductRank  -- Rank products within each purchase type
    FROM 
        ProductSales
)

SELECT 
    PurchaseType,
    ProductName,
    TotalQuantity
FROM 
    RankedProducts
WHERE 
    ProductRank <= 5  -- Limit to top 5 products for each purchase type
ORDER BY 
    PurchaseType, 
    TotalQuantity DESC;  -- Order by purchase type and quantity



--Seasonal Trends (by year, quarter, and sales type)
SELECT 
    YEAR(OrderDate) AS SalesYear,
    DATEPART(QUARTER, OrderDate) AS SalesQuarter,
    CASE 
        WHEN OnlineOrderFlag = 1 THEN 'Online Sales' 
        ELSE 'Physical Store Sales' 
    END AS SalesType,
    SUM(TotalDue) AS TotalSales,
    SUM(TotalDue) * 100.0 / SUM(SUM(TotalDue)) OVER (PARTITION BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate)) AS PercentageOfSales
FROM 
    Sales.SalesOrderHeader
GROUP BY 
    YEAR(OrderDate), 
    DATEPART(QUARTER, OrderDate), 
    OnlineOrderFlag
ORDER BY 
    SalesYear, 
    SalesQuarter, 
    SalesType;


--Sales type broken down by territory
WITH SalesSummary AS (
    SELECT 
        st.Name AS Territory,
        CASE 
            WHEN soh.OnlineOrderFlag = 1 THEN 'Online Sales' 
            ELSE 'Physical Store Sales' 
        END AS SalesType,
        COUNT(soh.SalesOrderID) AS NumberOfOrders
    FROM 
        Sales.SalesOrderHeader AS soh
    JOIN 
        Sales.SalesTerritory AS st ON soh.TerritoryID = st.TerritoryID
    GROUP BY 
        st.Name, 
        soh.OnlineOrderFlag
)

SELECT 
    Territory,
    SalesType,
    NumberOfOrders,
    NumberOfOrders * 100.0 / SUM(NumberOfOrders) OVER (PARTITION BY Territory) AS PercentageOfOrders
FROM 
    SalesSummary
ORDER BY 
    Territory, 
    SalesType;

--Break down of individuals and shops by sales type
WITH CustomerCounts AS (
    SELECT 
        CASE 
            WHEN c.StoreID IS NULL THEN 'Individual' 
            ELSE 'Shop' 
        END AS IsStore,
        CASE 
            WHEN soh.OnlineOrderFlag = 1 THEN 'Online Customers' 
            ELSE 'Physical Store Customers' 
        END AS CustomerType,
        COUNT(DISTINCT soh.CustomerID) AS CustomerCount,
        COUNT(soh.SalesOrderID) AS TotalOrders  -- Count the total orders
    FROM 
        Sales.SalesOrderHeader AS soh
    JOIN 
        Sales.Customer AS c ON soh.CustomerID = c.CustomerID
    WHERE 
        c.PersonID IS NOT NULL  -- Exclude stores, only consider individual customers
    GROUP BY 
        CASE 
            WHEN c.StoreID IS NULL THEN 'Individual' 
            ELSE 'Shop' 
        END,
        CASE 
            WHEN soh.OnlineOrderFlag = 1 THEN 'Online Customers' 
            ELSE 'Physical Store Customers' 
        END
),

-- Generate all combinations of IsStore and CustomerType
AllCombinations AS (
    SELECT 
        IsStore,
        CustomerType
    FROM 
        (SELECT 'Individual' AS IsStore UNION ALL SELECT 'Shop') AS isstore
    CROSS JOIN 
        (SELECT 'Online Customers' AS CustomerType UNION ALL SELECT 'Physical Store Customers') AS customertype
)

SELECT 
    ac.IsStore,
    ac.CustomerType,
    COALESCE(SUM(cc.CustomerCount), 0) AS TotalCustomers,
    COALESCE(SUM(cc.TotalOrders), 0) AS TotalOrders  -- Sum the total orders
FROM 
    AllCombinations AS ac
LEFT JOIN 
    CustomerCounts AS cc ON ac.IsStore = cc.IsStore AND ac.CustomerType = cc.CustomerType
GROUP BY 
    ac.IsStore,
    ac.CustomerType
ORDER BY 
    ac.IsStore, 
    ac.CustomerType;

