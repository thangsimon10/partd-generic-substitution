-- 02_metrics.sql  |  drug x specialty targeting and savings sizing
--
-- CAVEAT ON `prescribers`: pre-aggregation happens at drug x BRAND x specialty,
-- so summing prescriber counts up to drug x specialty double-counts anyone who
-- prescribed more than one brand of the same molecule. It is an upper bound on
-- panel size, used only to gauge campaign reach, and never in a savings figure.
-- Runs on partd_classified (sql/04_orange_book.sql), never on raw names.
-- Definitions live in metric_dictionary.md. Every ratio is summed numerator
-- over summed denominator, never an average of per-row ratios.

-- Drugs excluded from the ranking, each with its reason recorded.
CREATE OR REPLACE TABLE exclusions AS
SELECT * FROM (VALUES
  ('LEVOTHYROXINE SODIUM','narrow therapeutic index - brand persistence is clinically defensible'),
  ('WARFARIN SODIUM',     'narrow therapeutic index - brand persistence is clinically defensible'),
  ('DIGOXIN',             'narrow therapeutic index'),
  ('PHENYTOIN SODIUM',    'narrow therapeutic index'),
  ('CARBAMAZEPINE',       'narrow therapeutic index'),
  ('LITHIUM CARBONATE',   'narrow therapeutic index'),
  ('THEOPHYLLINE',        'narrow therapeutic index'),
  ('CYCLOSPORINE',        'narrow therapeutic index'),
  ('TACROLIMUS',          'narrow therapeutic index'),
  ('AMOXICILLIN',         'short course - fills bottom-coded at 1.0 understates cost per fill'),
  ('AZITHROMYCIN',        'short course - fills bottom-coded at 1.0 understates cost per fill'),
  ('CEPHALEXIN',          'short course - fills bottom-coded at 1.0 understates cost per fill'),
  ('DOXYCYCLINE HYCLATE', 'short course - fills bottom-coded at 1.0 understates cost per fill'),
  ('CIPROFLOXACIN HCL',   'short course - fills bottom-coded at 1.0 understates cost per fill'),
  ('PREDNISONE',          'short course - fills bottom-coded at 1.0 understates cost per fill')
) AS t(generic_name, exclusion_reason);

-- Molecule level. Only small molecules with a pharmacy-substitutable (TE code
-- A*) generic on the market can be the target of a generic substitution
-- campaign. Rows whose classification is unknown or ambiguous are held out of
-- both numerator and denominator rather than assumed either way.
CREATE OR REPLACE TABLE molecule_year AS
SELECT
    data_year,
    generic_name,
    SUM(CASE WHEN classification='brand'   THEN fills_30day END) AS brand_fills,
    SUM(CASE WHEN classification='brand'   THEN drug_cost   END) AS brand_cost,
    SUM(CASE WHEN classification='generic' THEN fills_30day END) AS generic_fills,
    SUM(CASE WHEN classification='generic' THEN drug_cost   END) AS generic_cost,
    SUM(CASE WHEN classification='brand'   THEN drug_cost END)
      / NULLIF(SUM(CASE WHEN classification='brand'   THEN fills_30day END),0) AS brand_cpf,
    SUM(CASE WHEN classification='generic' THEN drug_cost END)
      / NULLIF(SUM(CASE WHEN classification='generic' THEN fills_30day END),0) AS generic_cpf,
    SUM(CASE WHEN classification IS NULL OR classification='ambiguous'
             THEN drug_cost END)                                 AS unclassified_cost,
    ANY_VALUE(price_gap_reliable)                                AS price_gap_reliable,
    ANY_VALUE(generic_only_forms)                                AS generic_only_forms
FROM partd_classified
WHERE in_orange_book_scope AND sub_generic_exists
GROUP BY 1,2;

CREATE OR REPLACE TABLE molecule_candidates AS
SELECT
    m.generic_name,
    m.brand_fills,
    m.brand_cost,
    ROUND(m.brand_cpf,2)                                   AS brand_cpf,
    ROUND(m.generic_cpf,2)                                 AS generic_cpf,
    ROUND(m.brand_cpf - m.generic_cpf,2)                   AS price_gap,
    ROUND(100.0*m.brand_fills/NULLIF(m.brand_fills+m.generic_fills,0),1) AS brand_share_pct,
    ROUND(m.brand_fills * (m.brand_cpf - m.generic_cpf),0) AS gross_opportunity,
    m.price_gap_reliable,
    m.generic_only_forms,
    -- Criterion 4: is the market already converting without us?
    ROUND(100.0*p.brand_fills/NULLIF(p.brand_fills+p.generic_fills,0),1) AS brand_share_prior,
    ROUND(100.0*m.brand_fills/NULLIF(m.brand_fills+m.generic_fills,0)
        - 100.0*p.brand_fills/NULLIF(p.brand_fills+p.generic_fills,0),1) AS brand_share_chg_pp,
    ROUND(100.0*(m.brand_fills/NULLIF(p.brand_fills,0) - 1),1)           AS brand_fills_yoy_pct
FROM molecule_year m
LEFT JOIN molecule_year p
  ON p.generic_name = m.generic_name AND p.data_year = m.data_year - 1
WHERE m.data_year = (SELECT MAX(data_year) FROM molecule_year)
  AND m.brand_fills   IS NOT NULL
  AND m.generic_fills IS NOT NULL
  AND m.brand_cpf > m.generic_cpf
  AND m.generic_name NOT IN (SELECT generic_name FROM exclusions);

-- Where the brand volume actually sits. This is the campaign target.
CREATE OR REPLACE TABLE target_candidates AS
SELECT
    c.generic_name,
    s.specialty,
    ROUND(s.brand_fills,0)                                  AS brand_fills,
    ROUND(s.brand_cost,0)                                   AS brand_cost,
    s.prescribers,
    c.brand_cpf, c.generic_cpf, c.price_gap, c.brand_share_pct,
    ROUND(s.brand_fills * c.price_gap * 0.10,0)             AS save_10,
    ROUND(s.brand_fills * c.price_gap * 0.25,0)             AS save_25,
    ROUND(s.brand_fills * c.price_gap * 0.40,0)             AS save_40
FROM molecule_candidates c
JOIN (
    SELECT generic_name, specialty,
           SUM(fills_30day)  AS brand_fills,
           SUM(drug_cost)    AS brand_cost,
           SUM(prescribers)  AS prescribers   -- upper bound; see header caveat
    FROM partd_classified
    WHERE classification='brand' AND in_orange_book_scope AND sub_generic_exists
      AND data_year = (SELECT MAX(data_year) FROM partd_classified)
    GROUP BY 1,2
) s ON s.generic_name = c.generic_name;
