-- 04_orange_book.sql  |  authoritative brand/generic classification
-- Source: FDA Orange Book (Approved Drug Products with Therapeutic Equivalence
-- Evaluations), EOBZIP_2026_08, products.txt, tilde-delimited.
--
-- Why this exists: the CMS Part D file carries no brand/generic indicator, and
-- Brnd_Name is populated on generic rows with a variant spelling of the generic
-- name, so no in-file rule can classify. See metric_dictionary.md metric 6.
--
-- Appl_Type N = NDA (brand), A = ANDA (generic)
-- TE_Code starting with A = therapeutically equivalent, pharmacy-substitutable

CREATE OR REPLACE TABLE ob_products AS
SELECT
    UPPER(TRIM(Ingredient)) AS ingredient,
    UPPER(TRIM(Trade_Name)) AS trade_name,
    Appl_Type               AS appl_type,
    TE_Code                 AS te_code,
    Type                    AS mkt_type,
    UPPER(TRIM(Strength))   AS strength,
    UPPER(TRIM("DF;Route")) AS df_route
FROM read_csv($OB_PRODUCTS, delim='~', header=true, quote='', sample_size=-1);

CREATE OR REPLACE TABLE ob_trade AS
SELECT trade_name,
       MAX(CASE WHEN appl_type='N' THEN 1 ELSE 0 END)=1 AS has_nda,
       MAX(CASE WHEN appl_type='A' THEN 1 ELSE 0 END)=1 AS has_anda
FROM ob_products GROUP BY 1;

-- A generic existing for the INGREDIENT is not enough. Bimatoprost showed why:
-- Lumigan 0.01% (AB) is the marketed brand, while most marketed bimatoprost
-- generics are AT-rated products at a different strength, corresponding to
-- Latisse / the discontinued 0.03% solution. They cannot be dispensed against a
-- Lumigan prescription, so an ingredient-level match invents savings that no
-- pharmacy could realise.
--
-- substitutable_generic_exists therefore requires a MARKETED generic sharing
-- BOTH strength and dosage form with a MARKETED brand, and carrying an A* TE
-- code. mkt_type DISCN products are discontinued and excluded.
CREATE OR REPLACE TABLE ob_pairs AS
SELECT DISTINCT b.ingredient, b.strength, b.df_route
FROM ob_products b
JOIN ob_products g
  ON g.ingredient = b.ingredient
 AND g.strength   = b.strength
 AND g.df_route   = b.df_route
WHERE b.appl_type='N' AND b.mkt_type <> 'DISCN'
  AND g.appl_type='A' AND g.mkt_type <> 'DISCN'
  AND g.te_code LIKE 'A%';

-- CMS carries NO strength field - Gnrc_Name is the ingredient alone. So when a
-- molecule is marketed at several strengths or dosage forms, the CMS generic
-- cost per fill is an average across all of them and the brand-vs-generic price
-- gap is NOT a like-for-like comparison.
--
-- Bimatoprost is the worked example. Lumigan 0.01% ophthalmic DOES have an
-- AB-rated 0.01% generic, so it is a legitimate target - but CMS "generic
-- bimatoprost" at $52/fill blends that 0.01% generic with cheaper, higher-
-- volume 0.03% products (the Latisse-equivalent topical and the generics of
-- the discontinued 0.03% ophthalmic). The $210 gap is therefore overstated for
-- the substitution actually on offer.
--
-- price_gap_reliable asks the right question. Multiple STRENGTHS are normal and
-- harmless: brand and generic both span 5mg through 25mg and the averages stay
-- comparable. The distortion comes from strength/form combinations where a
-- MARKETED GENERIC EXISTS BUT NO MARKETED BRAND DOES. Those generic-only
-- products sit in the CMS generic average while being irrelevant to the
-- substitution on offer, and they drag the generic cost per fill down.
--
-- Bimatoprost again: generic 0.03% ophthalmic solution is marketed, but brand
-- Lumigan 0.03% ophthalmic is DISCONTINUED. That cheap, high-volume generic
-- pollutes the average against which Lumigan 0.01% is compared.
CREATE OR REPLACE TABLE ob_forms AS
WITH marketed AS (
  SELECT ingredient, strength, df_route, appl_type, te_code
  FROM ob_products WHERE mkt_type <> 'DISCN'
),
brand_forms AS (
  SELECT DISTINCT ingredient, strength, df_route FROM marketed WHERE appl_type='N'
),
generic_forms AS (
  SELECT DISTINCT ingredient, strength, df_route FROM marketed
  WHERE appl_type='A' AND te_code LIKE 'A%'
)
SELECT
    COALESCE(b.ingredient, g.ingredient)                                AS ingredient,
    COUNT(DISTINCT CASE WHEN b.strength IS NOT NULL
          THEN b.strength || '|' || b.df_route END)                     AS brand_forms,
    COUNT(DISTINCT CASE WHEN g.strength IS NOT NULL
          THEN g.strength || '|' || g.df_route END)                     AS generic_forms,
    COUNT(DISTINCT CASE WHEN b.strength IS NULL
          THEN g.strength || '|' || g.df_route END)                     AS generic_only_forms
FROM brand_forms b
FULL OUTER JOIN generic_forms g
  ON g.ingredient = b.ingredient AND g.strength = b.strength AND g.df_route = b.df_route
GROUP BY 1;

CREATE OR REPLACE TABLE ob_ingredient AS
SELECT p.ingredient,
       MAX(CASE WHEN p.appl_type='A' THEN 1 ELSE 0 END)=1 AS generic_exists,
       (MAX(CASE WHEN q.ingredient IS NOT NULL THEN 1 ELSE 0 END)=1)
         AS substitutable_generic_exists,
       MAX(f.generic_only_forms)                   AS generic_only_forms,
       (COALESCE(MAX(f.generic_only_forms),0) = 0) AS price_gap_reliable
FROM ob_products p
LEFT JOIN (SELECT DISTINCT ingredient FROM ob_pairs) q ON q.ingredient = p.ingredient
LEFT JOIN ob_forms f ON f.ingredient = p.ingredient
GROUP BY 1;

-- Two things this view makes explicit, both of which change the analysis.
--   1. classification IS NULL means UNKNOWN. Never read it as generic.
--   2. in_orange_book_scope = false means the drug is a BIOLOGIC (BLA) or
--      vaccine. The Orange Book covers small molecules only. Biologics have
--      biosimilars, not generics, and their substitution turns on FDA
--      interchangeability rather than TE code, so excluding them from a
--      GENERIC substitution campaign is correct scope, not a coverage gap.
--
-- CMS appends device and presentation suffixes that FDA does not carry
-- (Pen, Sureclick, Solostar, Flextouch, Hfa, U-200, "(2 Pens)", "(Cf)").
-- The exact trade name is tried first, the stripped name second.
-- Built on drug_specialty_year (pre-aggregated in 01_load), not on the 56 M-row
-- prescriber table. The join key is a drug NAME, so aggregating first costs
-- nothing analytically and takes the join from tens of millions of rows to tens
-- of thousands.
CREATE OR REPLACE TABLE partd_classified AS
WITH norm AS (
  SELECT p.*,
    TRIM(REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(UPPER(TRIM(p.brand_name)), '\([^)]*\)', ' ', 'g'),
        '\s+(PEN|PENS|SURECLICK|SOLOSTAR|FLEXTOUCH|FLEXPEN|KWIKPEN|SENSOREADY|SYRINGE|AUTOINJECTOR|AUTO-INJECTOR|HFA|DISKUS|RESPICLICK|U-100|U-200|U-300|CF|PF)$',
        '', 'g'),
      '\s+', ' ', 'g')) AS brand_norm
  FROM drug_specialty_year p
)
SELECT n.*,
  CASE WHEN t.trade_name IS NULL         THEN NULL
       WHEN t.has_nda AND NOT t.has_anda THEN 'brand'
       WHEN t.has_anda AND NOT t.has_nda THEN 'generic'
       ELSE 'ambiguous' END               AS classification,
  (i.ingredient IS NOT NULL)              AS in_orange_book_scope,
  i.substitutable_generic_exists          AS sub_generic_exists,
  i.price_gap_reliable                    AS price_gap_reliable,
  i.generic_only_forms                    AS generic_only_forms
FROM norm n
LEFT JOIN ob_trade t
       ON t.trade_name = CASE
            WHEN EXISTS (SELECT 1 FROM ob_trade x WHERE x.trade_name = UPPER(TRIM(n.brand_name)))
            THEN UPPER(TRIM(n.brand_name)) ELSE n.brand_norm END
LEFT JOIN ob_ingredient i ON i.ingredient = n.generic_name;
