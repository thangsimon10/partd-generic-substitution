-- 03_validation.sql  |  every check returns PASS or FAIL plus its evidence.
-- Run before any number leaves this repo.

SELECT '01 row count by year' AS check,
       'INFO' AS result,
       data_year || ': ' || COUNT(*) AS evidence
FROM partd GROUP BY data_year

UNION ALL SELECT '02 no duplicate npi-brand-generic keys',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' duplicate keys'
FROM (SELECT data_year, npi, COALESCE(brand_name,''), generic_name
      FROM partd GROUP BY 1,2,3,4 HAVING COUNT(*)>1)

UNION ALL SELECT '03 min claims = 11 (CMS drops <=10 claims)',
       CASE WHEN MIN(claims)>=11 THEN 'PASS' ELSE 'FAIL' END,
       'min claims = ' || MIN(claims)
FROM partd

UNION ALL SELECT '04 30-day fills >= claims (fills bottom-coded at 1.0)',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' rows violate'
FROM partd WHERE fills_30day < claims

-- 05 split after investigating the real DY2024 file. Zero-cost rows are almost
-- entirely Paxlovid (nirmatrelvir/ritonavir), federally supplied at no cost to
-- Part D during the covered period - legitimate data, not an error. Negative
-- cost would indicate an unnetted reversal and remains a hard failure.
UNION ALL SELECT '05a no negative cost',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' rows < 0'
FROM partd WHERE drug_cost < 0

UNION ALL SELECT '05b zero-cost rows (expected: federally supplied drugs)',
       'INFO',
       COUNT(*) || ' rows, top drug: ' || MAX(generic_name)
FROM partd WHERE drug_cost = 0

UNION ALL SELECT '06 benes <= claims where benes present',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' rows violate'
FROM partd WHERE benes IS NOT NULL AND benes > claims

UNION ALL SELECT '07 ge65 flag domain is * # or null',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' rows with unexpected flag'
FROM partd WHERE ge65_flag IS NOT NULL AND ge65_flag NOT IN ('*','#')

UNION ALL SELECT '08 suppressed-bene share (reported, not a pass/fail)',
       'INFO',
       ROUND(100.0*SUM(CASE WHEN benes_suppressed THEN 1 ELSE 0 END)/COUNT(*),1)
         || '% of rows, '
       || ROUND(100.0*SUM(CASE WHEN benes_suppressed THEN claims ELSE 0 END)/SUM(claims),1)
         || '% of claims'
FROM partd

-- 09 bounds set by investigation, not by guess.
--   Upper: raised from $25k to $600k. Ultra-rare therapies legitimately exceed
--   $25k per 30-day fill (elapegademase for ADA-SCID, icatibant and ecallantide
--   for hereditary angioedema): 8,126 rows carrying $6.3B of real spend.
--   Lower: no floor. 236 rows sit below $0.01 per fill - long-off-patent
--   generics (atenolol, lovastatin, glipizide) that cost effectively nothing.
--   Negative cost is the real failure mode and check 05a owns it.
UNION ALL SELECT '09 cost per 30-day fill at or below $600000',
       CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*) || ' rows above ceiling'
FROM partd WHERE drug_cost > 0
  AND drug_cost/NULLIF(fills_30day,0) > 600000

-- 10 two years are required for the trend the analysis calls for. Expected to
-- fail until DY2023 is downloaded. Left failing on purpose: a silenced check is
-- a forgotten check.
UNION ALL SELECT '10 both years present (needed for trend)',
       CASE WHEN COUNT(DISTINCT data_year)=2 THEN 'PASS' ELSE 'FAIL - DY2023 not yet downloaded' END,
       'years: ' || STRING_AGG(DISTINCT data_year::VARCHAR, ', ')
FROM partd
ORDER BY 1;
