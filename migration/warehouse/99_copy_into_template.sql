-- 99_copy_into_template.sql
-- Loads each stg.* table from Parquet files dropped into the lakehouse
-- under Files/raw/<table>.parquet.
--
-- Workspace: ws-ssis2fabric-demo
-- Lakehouse: lh_ssis_demo (id e3fcb33a-13d8-4967-add9-5efed6fcac65)
-- OneLake path pattern:
--   https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/<table>.parquet
--
-- CREDENTIAL note: when the COPY INTO is executed by a caller already
-- authenticated to Fabric via Entra ID, omitting the WITH (CREDENTIAL = ...)
-- clause makes Fabric Warehouse use the caller's identity (Workspace
-- Identity at runtime, the deploying user from sqlcmd). That is the
-- simplest pattern and is what we use below. If you need to override,
-- swap in:
--   WITH (
--       FILE_TYPE = 'PARQUET',
--       CREDENTIAL = (IDENTITY = 'Managed Identity')
--   )

COPY INTO stg.CountryLookup
FROM 'https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/CountryLookup.parquet'
WITH (FILE_TYPE = 'PARQUET');

COPY INTO stg.Customers
FROM 'https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/Customers.parquet'
WITH (FILE_TYPE = 'PARQUET');

COPY INTO stg.Products
FROM 'https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/Products.parquet'
WITH (FILE_TYPE = 'PARQUET');

COPY INTO stg.Orders
FROM 'https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/Orders.parquet'
WITH (FILE_TYPE = 'PARQUET');

COPY INTO stg.OrderItems
FROM 'https://onelake.dfs.fabric.microsoft.com/ws-ssis2fabric-demo/lh_ssis_demo.Lakehouse/Files/raw/OrderItems.parquet'
WITH (FILE_TYPE = 'PARQUET');
