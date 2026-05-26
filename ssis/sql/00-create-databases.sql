/*
  00-create-databases.sql
  Create the SalesSrc (source OLTP) and SalesDW (target DW) databases.
  Idempotent: skips creation if database already exists.
  Run against [master] on the demo VM via sqlcmd.
*/

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'SalesSrc')
BEGIN
    PRINT 'Creating database SalesSrc...';
    CREATE DATABASE [SalesSrc];
END
ELSE
    PRINT 'Database SalesSrc already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'SalesDW')
BEGIN
    PRINT 'Creating database SalesDW...';
    CREATE DATABASE [SalesDW];
END
ELSE
    PRINT 'Database SalesDW already exists.';
GO

ALTER DATABASE [SalesSrc] SET RECOVERY SIMPLE;
ALTER DATABASE [SalesDW]  SET RECOVERY SIMPLE;
GO
