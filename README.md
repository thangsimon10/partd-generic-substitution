# Where to aim a generic substitution campaign

**A Medicare Advantage plan can fund one generic-substitution campaign next year. Which drug, which prescriber specialty, and what is it worth?**

Built from CMS Medicare Part D prescriber data (DY2023 + DY2024, 54.8M rows), classified against the FDA Orange Book.

## The answer

Target **icosapent ethyl (Vascepa)** among internal medicine and family practice.

At a 25% substitution rate: **~$40M** from those two specialties, **~$71M** across all of them. National Part D basis, gross of manufacturer rebates.

Full reasoning in `memo.md`.

## Why not the biggest number

Ranked by gross opportunity, the winner is lenalidomide at $891M — and it is close to unactionable. Revlimid is REMS-restricted, distributed through specialty pharmacy, prescribed by oncologists, and its generic supply is capped by patent settlement. Prescriber outreach cannot move it.

The criterion that actually sorted the list was different: **is the market already converting without us?**

| Molecule | Brand share change, DY2023 to DY2024 |
| --- | --- |
| Teriflunomide | -38.9 pp |
| Lenalidomide | -10.5 pp |
| Glatiramer acetate | -7.2 pp |
| Dimethyl fumarate | -5.7 pp |
| Tiotropium | -4.7 pp |
| **Icosapent ethyl** | **+2.2 pp** |

A campaign aimed at a falling molecule reports a win that was going to happen anyway. Icosapent ethyl is the only large candidate whose brand share is rising, on 1.81M brand fills with a $156 per-fill gap and AB-rated generics long on the market.

## Two traps this analysis handles

**The CMS file has no brand/generic indicator.** Its Brnd_Name column is populated on generic rows too, carrying a variant spelling of the generic name - Brnd_Name "Lovastatin" against Gnrc_Name "LOVASTATIN" is a generic. Any name-comparison rule misclassifies in the direction that inflates savings. Classification comes from the FDA Orange Book application type (NDA vs ANDA) instead. See `metric_dictionary.md`, metric 6.

**CMS carries no strength field.** Bimatoprost looked like a $468M opportunity until strength-level checking showed the cheap "generic" in the average was a 0.03% product that cannot be dispensed against a Lumigan 0.01% prescription. Candidates now require a marketed, A-rated generic at a matching strength and dosage form.

## Validation

Ten checks in `sql/03_validation.sql`, all passing on 54,818,770 rows. Two failed on the first run and both turned out to be the data being right:

- 28,583 rows at exactly $0 - Paxlovid, federally supplied at no cost to Part D
- 282,074 rows outside the expected per-fill price band - ultra-rare disease therapies above it ($6.3B of real spend), long-off-patent generics below it

Thresholds were widened with the investigation recorded beside each check.

No tie-out to a national Part D total is possible: CMS excludes prescriber-drug records with 10 or fewer claims, so the published file is a subset by construction.

## What is here

    sql/01_load.sql          load two years, pre-aggregate to drug x specialty
    sql/02_metrics.sql       targeting, price gaps, savings at three rates
    sql/03_validation.sql    ten checks, PASS/FAIL with evidence
    sql/04_orange_book.sql   brand/generic classification, strength-matched
    run_pipeline.py          rebuilds the analysis end to end
    sqlutil.py               SQL statement splitter that survives comments
    metric_dictionary.md     every metric defined before the SQL was written
    memo.md                  the one-page answer

The raw CMS files are 7.4 GB and are not in this repo. Download links are in the Sources section below; point `run_pipeline.py` at them and it rebuilds everything.

Figures, the Excel model and the slide deck live outside the repo for now.

## Limitations

1. **Gross of rebates.** Manufacturer rebates are confidential. Real net savings are lower and cannot be derived from public data.
2. **National, not plan-level.** A plan sees its own share of these figures.
3. **The 25% substitution rate is an assumption**, reasoned from published academic-detailing results against a Part D generic dispensing rate already near 90%. Metric 8 in the dictionary shows the reasoning for all three rates.
4. **Biologics excluded** - $80.8B, 35.6% of spend. They have biosimilars rather than generics, and substitution turns on FDA interchangeability. That is a separate analysis and the largest unexamined opportunity here.

## Sources

- CMS Medicare Part D Prescribers by Provider and Drug: https://data.cms.gov/provider-summary-by-type-of-service/medicare-part-d-prescribers/medicare-part-d-prescribers-by-provider-and-drug
- FDA Orange Book data files (EOBZIP_2026_08): https://www.fda.gov/drugs/drug-approvals-and-databases/orange-book-data-files
