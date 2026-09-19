# Target icosapent ethyl among internal medicine and family practice: $40M at a 25% substitution rate

**Question.** If the pharmacy team can run one generic-substitution campaign next
year, which drug and which prescriber specialty should it target, and what is
the prize?

**Answer.** Icosapent ethyl (brand Vascepa). Brand share is **76.3%** of fills
despite AB-rated generics being widely marketed, and it is the only large
candidate where brand share is **rising** (+2.2 points year over year). Internal
medicine and family practice write 57% of the brand volume.

**Recommendation.** Run prescriber outreach on icosapent ethyl, scoped to
internal medicine and family practice first, then nurse practitioners and
cardiology. Expected gross savings, national Part D basis, at a 25% conversion
of addressable brand fills: **$40M** for the first two specialties, **$58M**
across the top four, **$71M** across all specialties.

## What the data shows

**Icosapent ethyl is the one large molecule the market is not converting on its
own.** Across DY2023 to DY2024 the other high-value candidates are already
moving to generic without help: teriflunomide brand share fell 38.9 points,
glatiramer 7.2, dimethyl fumarate 5.7, tiotropium 4.7. Icosapent ethyl went the
other way, **+2.2 points**, on 1.81M brand 30-day fills. A campaign there causes
conversion rather than taking credit for it.

**The price gap is large and like-for-like.** Brand costs $311 per 30-day fill
against $154 for the generic, a **$156 gap**. Vascepa and its AB-rated generics
are marketed at the same strengths and dosage forms, so the comparison is not
distorted by strength mix - a check that disqualified three otherwise
attractive candidates.

**The volume is concentrated enough to reach.** Four specialties hold 82% of
brand fills.

| Specialty | Brand 30-day fills | Savings @10% | @25% | @40% |
| --- | ---: | ---: | ---: | ---: |
| Internal Medicine | 664,707 | $10.4M | $26.0M | $41.6M |
| Family Practice | 358,521 | $5.6M | $14.0M | $22.4M |
| Nurse Practitioner | 245,285 | $3.8M | $9.6M | $15.4M |
| Cardiology | 215,975 | $3.4M | $8.4M | $13.5M |
| **All specialties** | **1,809,060** | **$28.3M** | **$70.8M** | **$113.2M** |

## Why not the bigger number

Lenalidomide shows an $891M gross opportunity - three times icosapent ethyl - and
it is the wrong target. Revlimid is REMS-restricted, distributed through
specialty pharmacy, prescribed by oncologists, and its generic entry is
volume-capped by patent settlement. Prescriber outreach cannot move it. Ranking
by opportunity size alone would have picked it.

Tiotropium is the credible runner-up: 95.2% brand share on 1.30M fills, $126M
gross. It is held back only because inhaler substitution involves a device
change, which makes it a harder clinical ask than swapping a capsule.

## How confident I am

**The direction is solid; the dollar figure is an estimate with a stated rate.**
Three things would change the answer:

1. **Rebates.** Total drug cost in this file is gross of manufacturer rebates,
   which are confidential. If Vascepa carries a substantial rebate, net savings
   are materially lower. This is the single largest uncertainty and it cannot be
   resolved from public data - check the plan's actual contract before funding.
2. **The substitution rate.** 25% is the central case, reasoned from a published
   academic-detailing program and from the fact that Part D generic dispensing
   already runs at ~90%, so residual brand fills are residual for a reason
   (DAW codes, prior intolerance). 10% is the number to defend to a CFO.
3. **Scale.** These are **national Part D** figures. A plan sees its own share:
   roughly 1% of national Part D lives implies roughly 1% of these dollars.
   Rerun on plan-internal claims before committing a budget.

**What I could not check:** whether existing formulary controls already restrict
Vascepa, and whether the residual brand fills carry DAW-1 prescriber-mandated
codes - which would cap achievable conversion well below 25%.

## Method and validation

Source: CMS Medicare Part D Prescribers by Provider and Drug, DY2023 and DY2024,
54.8M rows. Brand/generic classification from the FDA Orange Book,
EOBZIP_2026_08 - the CMS file carries no brand/generic indicator and Brnd_Name
is populated on generic rows, so no in-file rule works.

Ten validation checks, all passing. Traps handled and disclosed:

- CMS **excludes** prescriber-drug records with 10 or fewer claims, so this file
  is a subset of Part D and cannot reproduce a national total.
- Tot_Benes is blank when 1-10 - missing, not zero. 54.8% of rows.
- 30-day fills are bottom-coded at 1.0 per claim, understating cost per fill for
  short-course drugs. Antibiotics and steroid bursts excluded from ranking.
- Narrow-therapeutic-index molecules excluded: substitution there is a clinical
  error, not a saving.
- Biologics ($80.8B, 35.6% of spend) are out of scope: they have biosimilars,
  not generics, and substitution turns on FDA interchangeability. **This is the
  largest unexamined opportunity and warrants its own analysis.**
- Specialty labels are not stable year to year: 2.5% of prescribers present in
  both years changed label. Too small to affect this result, large enough to
  disclose.
