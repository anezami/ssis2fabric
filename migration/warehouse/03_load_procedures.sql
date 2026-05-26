-- 03_load_procedures.sql
-- Per-entity load procedures. Source = stg.* (already populated by
-- COPY INTO from OneLake -- see 99_copy_into_template.sql).
-- Surrogate keys are generated via ROW_NUMBER() because Fabric Warehouse
-- does not support IDENTITY columns.

CREATE OR ALTER PROCEDURE dw.usp_LoadDimCustomer
AS
BEGIN
    -- Initial-load semantics: clear and reload.
    DELETE FROM dw.DimCustomer;

    INSERT INTO dw.DimCustomer
        (CustomerKey, CustomerID, FullName, Email, CountryName,
         ValidFrom, ValidTo, IsCurrent)
    SELECT
        ROW_NUMBER() OVER (ORDER BY C.CustomerID) AS CustomerKey,
        C.CustomerID,
        C.FullName,
        C.Email,
        CL.CountryName,
        SYSUTCDATETIME() AS ValidFrom,
        CAST(NULL AS DATETIME2(6)) AS ValidTo,
        CAST(1 AS BIT) AS IsCurrent
    FROM stg.Customers C
    LEFT JOIN stg.CountryLookup CL
      ON CL.CountryName = C.Country;
END;
GO

CREATE OR ALTER PROCEDURE dw.usp_LoadDimProduct
AS
BEGIN
    DELETE FROM dw.DimProduct;

    INSERT INTO dw.DimProduct
        (ProductKey, ProductID, Sku, Name, Category, Price, MarginCategory)
    SELECT
        ROW_NUMBER() OVER (ORDER BY P.ProductID) AS ProductKey,
        P.ProductID,
        UPPER(P.Sku) AS Sku,
        P.Name,
        P.Category,
        P.Price,
        CASE
            WHEN P.Price < 50  THEN 'LOW'
            WHEN P.Price < 200 THEN 'MEDIUM'
            ELSE 'HIGH'
        END AS MarginCategory
    FROM stg.Products P;
END;
GO

CREATE OR ALTER PROCEDURE dw.usp_LoadFactOrders
AS
BEGIN
    DELETE FROM dw.FactOrders;

    INSERT INTO dw.FactOrders
        (OrderKey, OrderID, CustomerKey, OrderDate, TotalAmount, Status)
    SELECT
        ROW_NUMBER() OVER (ORDER BY O.OrderID) AS OrderKey,
        O.OrderID,
        DC.CustomerKey,
        O.OrderDate,
        O.TotalAmount,
        O.Status
    FROM stg.Orders O
    LEFT JOIN dw.DimCustomer DC
      ON DC.CustomerID = O.CustomerID
     AND DC.IsCurrent = 1;
END;
GO
