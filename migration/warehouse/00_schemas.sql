-- 00_schemas.sql
-- Idempotent creation of schemas in wh_ssis_demo.
-- Fabric Warehouse: CREATE SCHEMA must be the only statement in its batch,
-- so we wrap each in EXEC('...') to allow this file to be executed as a
-- single batch by the deploy script.

IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('dw')  IS NULL EXEC('CREATE SCHEMA dw');
