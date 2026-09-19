# Metric dictionary

Definitions are written before the SQL. Source of truth for field semantics is
the CMS Prescriber Methods documentation, not inference from the data.

---

### 1. Total drug cost

**Definition:** Aggregate cost paid for the drug, comprising ingredient cost,
dispensing fee, sales tax and any applicable vaccine administration fee,
**summed across all payers** (Medicare, beneficiary, and other).

**Field:** Tot_Drug_Cst  ·  **Grain:** prescriber x drug x year

**Critical caveat:** This is **gross of manufacturer rebates**. Rebates are
confidential and absent from public data. Any savings figure derived from this
field is a gross-of-rebate estimate and its true net value is lower and not
knowable from this source.

**Note:** it is *not* ingredient cost alone - a common misstatement.

### 2. 30-day standardized fills

**Definition:** Sum over claims of (days supply / 30), with each claim's value
**bottom-coded at 1.0 and top-coded at 12.0**.

**Field:** Tot_30day_Fills

**Why used:** A 90-day fill and a 30-day fill are both one claim. Claim counts
are not comparable across drugs with different typical days supply.

**Critical caveat:** Bottom-coding means a 5- or 7-day course (antibiotics,
steroid bursts) counts as a **full 1.0 fill**. Cost per 30-day fill is therefore
**understated for short-course drugs**. Exclude short-course therapies from any
cost-per-fill ranking, or the ranking is wrong.

### 3. Cost per 30-day fill

**Definition:** Tot_Drug_Cst / Tot_30day_Fills

**Grain of use:** aggregated to drug x specialty, computed on summed numerator
and summed denominator - never as an average of per-row ratios.

**Use:** the comparable unit price for brand vs generic.

### 4. Total beneficiaries

**Definition:** Distinct beneficiaries with at least one fill of that drug from
that prescriber.

**Field:** Tot_Benes

**Suppression:** **Blank when the value is 1-10.** Blank means MISSING, not zero.
Never sum or average this field without stating the suppressed share, and never
coalesce it to 0.

### 5. Record exclusion (not a metric - a population rule)

**Rule:** CMS **excludes entirely** any prescriber-drug record derived from
**10 or fewer claims**. These rows are absent from the file, not suppressed
within it.

**Consequence:** The file is a **subset** of Part D by construction. It cannot
reproduce a true national Part D total, and low-volume prescriber-drug pairs
are invisible. Any "share of national spend" statement must say it is share of
the published file.

### 6. Brand vs generic classification

**Status: NO RULE POSSIBLE FROM THIS FILE.**

Brnd_Name is populated on generic rows too, carrying a variant spelling of the
generic name:

    Brnd_Name "Abrysvo"               Gnrc_Name "Rsv Vacc, Pref A And Pref B/Pf"   BRAND
    Brnd_Name "Acetaminophen-Codeine" Gnrc_Name "Acetaminophen With Codeine"       GENERIC
    Brnd_Name "Lovastatin"            Gnrc_Name "LOVASTATIN"                       GENERIC

A name comparison would classify the second as brand, silently, across millions
of rows, and in the direction that **inflates** estimated savings. The file
carries 3,055 distinct Brnd_Name values against 1,823 Gnrc_Name values and no
brand/generic indicator of any kind.

**RESOLVED** by joining the FDA Orange Book (EOBZIP_2026_08, 48,761 products).
Appl_Type is authoritative: N = NDA (brand), A = ANDA (generic). TE_Code
beginning with A marks a therapeutically equivalent, pharmacy-substitutable
product - a better substitution test than any price heuristic.

Coverage on DY2024, after normalising CMS device suffixes (Pen, Sureclick,
Solostar, Hfa and similar) that the Orange Book does not carry:

| Population | Rows | Spend | Share of spend |
| --- | --- | --- | --- |
| Small molecule (in Orange Book) | 18,333,549 | $145.97 B | 64.4% |
| Biologic / vaccine (BLA, not in Orange Book) | 9,690,343 | $80.77 B | 35.6% |

**Within Orange Book scope, 97.8% of spend and 92.9% of rows classify.**

classification is NULL where no match exists. **NULL means unknown and must
never be read as generic.**

### 7. Estimated annual savings

**Definition:** addressable brand 30-day fills x (brand cost per 30-day fill
minus generic cost per 30-day fill) x substitution rate.

**Reported at three rates, never at 100%.**

**Caveat chain:** gross of rebates (metric 1), subset population (metric 5),
and excludes Part B physician-administered drugs entirely.

### 8. Substitution rates - the three cases and the reasoning

The rate is the share of **addressable residual brand fills** a prescriber
campaign converts within one plan year. It is not the share of all brand fills.

**Why the starting point is low.** Part D generic dispensing already runs at
roughly **90% of all prescriptions** (MedPAC, March 2025 report to Congress, on
2023 data). Where an A-rated generic of the same molecule exists, pharmacy-level
substitution is largely automatic under state substitution laws. The brand fills
that remain are residual **for a reason**: DAW-1 prescriber-mandated, DAW-2
patient-requested, a documented prior intolerance, or a narrow therapeutic
index. A campaign works on that residue, and the residue resists.

| Case | Rate | Reasoning |
| --- | --- | --- |
| Conservative | **10%** | Floor. Assumes most residual brand fills carry a DAW code or a clinical reason, and that low-touch outreach (letter, portal alert, quarterly report card) moves only the uncommitted share. The number to defend to a CFO. |
| Base | **25%** | Central estimate. A published health-plan academic detailing program achieved roughly a **36% reduction** in target-drug prescriptions with **82% of targeted prescribers responsive**, but on a small, hand-selected panel (11 prescribers, 50 pharmacist hours). Scaled to a specialty-wide campaign at lower touch intensity per prescriber, a quarter of addressable fills is the defensible middle. |
| Optimistic | **40%** | Ceiling, not a forecast. Approaches the effect size observed in that high-touch program. Achievable only with pharmacist-led one-to-one outreach on a concentrated panel, and only where no DAW barrier dominates. Present it as an upper bound. |

**Sources.** Academic detailing effect size: *Academic Detailing Has a Positive
Effect on Prescribing and Decreasing Prescription Drug Costs: A Health Plan's
Perspective*, Am Health Drug Benefits 2017 (PMC5470238). Part D generic
dispensing rate: MedPAC, *Status report on the Medicare prescription drug
program (Part D)*, March 2025, Chapter 12.

**How to report it:** lead with the base case, show all three, and state the
rate in the same sentence as the dollar figure. A savings number without its
assumed rate attached is not a finding.

### 9. Addressability filter - apply before any rate

A molecule qualifies as a campaign target only if all hold:

1. A generic of the **same molecule** exists (not a therapeutic substitute -
   therapeutic interchange is a different, clinically harder ask).
2. Brand cost per 30-day fill exceeds generic cost per 30-day fill.
3. It is not on the exclusion list (short-course or narrow therapeutic index).
4. **Brand share is still material and not already collapsing.** This is the
   criterion most analyses miss. A molecule whose brand share is falling steeply
   year over year is converting on its own; a campaign there takes credit for a
   trend it did not cause. The real opportunity is high residual brand share
   that is **flat or rising** - the market has stopped converting by itself.

---

## Open questions, and what the data answered

1. ~~Brnd_Name convention on generic rows~~ - **ANSWERED**, see metric 6. No
   in-file rule exists; an external brand reference is required.
2. ~~Specialty stability across years~~ - **ANSWERED, and it is not stable.**
   NPI 1003000126 is Hospitalist in DY2023 and Internal Medicine in DY2024.
   Across both years, 2.5% of prescribers changed label. Since the analysis
   aggregates by specialty, a naive year-over-year comparison reads relabelling
   as real volume movement. A specialty trend should be computed on the subset
   of NPIs whose label is unchanged, with the excluded share reported.
3. ~~Actual suppressed-beneficiary share~~ - **ANSWERED: 54.5% of rows, 21.3%
   of claims** in DY2024. Over half the rows carry no beneficiary count.
4. OPEN: does Prscrbr_Type_Src (Claim-Specialty vs other values) explain the
   year-over-year specialty churn?
5. OPEN: **$80.8 B of biologic spend is out of scope for generic substitution by
   definition.** Biologics have biosimilars, not generics, and substitution
   turns on FDA interchangeability designation rather than TE code. Sizing that
   needs the FDA Purple Book and is a separate analysis - the single largest
   "what I would do with more time" item.
6. OPEN: 4.3 M rows classify as ambiguous (a trade name carrying both NDA and
   ANDA approvals, $3.96 B). These need resolution at strength and dosage-form
   level rather than trade-name level before entering any savings figure.
