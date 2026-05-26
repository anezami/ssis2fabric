-- 04_load_orchestrator.sql
-- Orchestrator that runs the three load procs in dependency order
-- and writes one row per proc to dw.LoadLog. Wraps each call in
-- TRY/CATCH so a failure in one entity stops the chain but still
-- leaves a logged record explaining what happened.

CREATE OR ALTER PROCEDURE dw.usp_RunAll
AS
BEGIN
    DECLARE @started DATETIME2(6);
    DECLARE @logId   BIGINT;
    DECLARE @err     VARCHAR(4000);

    -- DimCustomer ------------------------------------------------------
    SET @started = SYSUTCDATETIME();
    SET @logId   = DATEDIFF_BIG(MILLISECOND, '2020-01-01', @started);
    INSERT INTO dw.LoadLog (LogID, ProcName, StartedUtc, Status)
    VALUES (@logId, 'dw.usp_LoadDimCustomer', @started, 'RUNNING');

    BEGIN TRY
        EXEC dw.usp_LoadDimCustomer;
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'SUCCESS',
               RowsAffected = (SELECT COUNT(*) FROM dw.DimCustomer)
         WHERE LogID = @logId;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'FAILED',
               ErrorMessage = @err
         WHERE LogID = @logId;
        THROW;
    END CATCH;

    -- DimProduct -------------------------------------------------------
    SET @started = SYSUTCDATETIME();
    SET @logId   = DATEDIFF_BIG(MILLISECOND, '2020-01-01', @started);
    INSERT INTO dw.LoadLog (LogID, ProcName, StartedUtc, Status)
    VALUES (@logId, 'dw.usp_LoadDimProduct', @started, 'RUNNING');

    BEGIN TRY
        EXEC dw.usp_LoadDimProduct;
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'SUCCESS',
               RowsAffected = (SELECT COUNT(*) FROM dw.DimProduct)
         WHERE LogID = @logId;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'FAILED',
               ErrorMessage = @err
         WHERE LogID = @logId;
        THROW;
    END CATCH;

    -- FactOrders (depends on DimCustomer) ------------------------------
    SET @started = SYSUTCDATETIME();
    SET @logId   = DATEDIFF_BIG(MILLISECOND, '2020-01-01', @started);
    INSERT INTO dw.LoadLog (LogID, ProcName, StartedUtc, Status)
    VALUES (@logId, 'dw.usp_LoadFactOrders', @started, 'RUNNING');

    BEGIN TRY
        EXEC dw.usp_LoadFactOrders;
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'SUCCESS',
               RowsAffected = (SELECT COUNT(*) FROM dw.FactOrders)
         WHERE LogID = @logId;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        UPDATE dw.LoadLog
           SET EndedUtc = SYSUTCDATETIME(),
               Status   = 'FAILED',
               ErrorMessage = @err
         WHERE LogID = @logId;
        THROW;
    END CATCH;
END;
GO
