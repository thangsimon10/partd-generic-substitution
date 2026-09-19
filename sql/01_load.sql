-- 01_load.sql  |  Part D Prescribers by Provider and Drug -> DuckDB
--
-- Raw files are read in place and never modified. Paths come from the runner.
-- Blank strings become NULL so suppressed cells stay MISSING, not zero.
--
-- ONLY THE COLUMNS THE ANALYSIS USES ARE READ. The file has 22; prescriber
-- name, city, FIPS, type source and the six GE65 numeric columns are not used
-- and reading them doubles the database for nothing. This machine has 3.8 GB of
-- RAM and 6.8 GB of free disk against two 28 M-row years, so the saving is the
-- difference between the pipeline running and being OOM-killed.

CREATE OR REPLACE TABLE partd_raw AS
SELECT 2023 AS data_year, Prscrbr_NPI, Prscrbr_Type, Prscrbr_State_Abrvtn,
       Brnd_Name, Gnrc_Name, Tot_Clms, Tot_30day_Fills, Tot_Day_Suply,
       Tot_Drug_Cst, Tot_Benes, GE65_Sprsn_Flag
FROM read_csv($RAW_2023, header=true, nullstr='', sample_size=-1,
              types={'Prscrbr_NPI':'BIGINT'})
UNION ALL BY NAME
SELECT 2024 AS data_year, Prscrbr_NPI, Prscrbr_Type, Prscrbr_State_Abrvtn,
       Brnd_Name, Gnrc_Name, Tot_Clms, Tot_30day_Fills, Tot_Day_Suply,
       Tot_Drug_Cst, Tot_Benes, GE65_Sprsn_Flag
FROM read_csv($RAW_2024, header=true, nullstr='', sample_size=-1,
              types={'Prscrbr_NPI':'BIGINT'});

-- Names arrive title-cased and Gnrc_Name contains commas inside quoted fields.
CREATE OR REPLACE VIEW partd AS
SELECT
    data_year,
    Prscrbr_NPI                     AS npi,
    TRIM(Prscrbr_Type)              AS specialty,
    Prscrbr_State_Abrvtn            AS state,
    NULLIF(TRIM(Brnd_Name),'')      AS brand_name,
    UPPER(TRIM(Gnrc_Name))          AS generic_name,
    CAST(Tot_Clms AS BIGINT)        AS claims,
    CAST(Tot_30day_Fills AS DOUBLE) AS fills_30day,
    CAST(Tot_Day_Suply AS BIGINT)   AS day_supply,
    CAST(Tot_Drug_Cst AS DOUBLE)    AS drug_cost,
    CAST(Tot_Benes AS BIGINT)       AS benes,
    (Tot_Benes IS NULL)             AS benes_suppressed,
    GE65_Sprsn_Flag                 AS ge65_flag
    -- is_brand is deliberately absent: see metric_dictionary.md metric 6.
FROM partd_raw;

-- PRE-AGGREGATION. The Orange Book join is on drug NAME, so it never needed to
-- touch 56 M prescriber-level rows. Collapsing to drug x specialty x year FIRST
-- takes the join from tens of millions of rows to tens of thousands. Everything
-- downstream reads this table, not the raw one.
CREATE OR REPLACE TABLE drug_specialty_year AS
SELECT
    data_year,
    generic_name,
    brand_name,
    specialty,
    COUNT(*)                        AS n_rows,
    COUNT(DISTINCT npi)             AS prescribers,
    SUM(claims)                     AS claims,
    SUM(fills_30day)                AS fills_30day,
    SUM(day_supply)                 AS day_supply,
    SUM(drug_cost)                  AS drug_cost,
    SUM(CASE WHEN benes_suppressed THEN 1 ELSE 0 END) AS rows_bene_suppressed
FROM partd
GROUP BY 1,2,3,4;
