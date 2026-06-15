# PROMPTS.md

This file documents the meaningful prompts used with Claude (Cowork) while building this project. I treated Claude as a sounding-board during this task, mainly pair-programming and debugging aid. SQL syntax, dbt error messages, data exploration, and deliverable formatting (deck, docs). The analytical decisions (metric definitions, how to treat edge cases, what the data was telling us) were made collaboratively, with the final call always mine.

---

## 1. Environment setup / troubleshooting

Used to get unblocked on local tooling so I could query `tracksuit.duckdb` directly rather than relying only on dbt runs.

---

## 2. Reviewing the dbt model structure

Asked for a structural review of the dimensional model (`dim_account`, `dim_date`, `fct_invoices`, `fct_subscription_renewals`, `rpt_grr_by_period`, staging models). Claude flagged a few minor issues. `_core.yml` column docs not matching actual SQL output, an unused join in `rpt_grr_by_period`, dead code in the HubSpot bridge model, and `retained_acv = 0` vs `null` for in-progress subscriptions. I reviewed each and decided which were worth fixing vs. cosmetic.

---

## 3. Investigating the HubSpot/Subskribe ID mismatch

Used to confirm the bridge table resolved all `hsold_` legacy IDs correctly, and to identify the 2 `hsmissing_` accounts (Wrenfield Brewing, Riverbend Co) with no CRM record.

---

## 4. Diagnosing why GRR declined sharply toward the present

This was the most consequential exchange. I noticed that GRR was declining in recent months, but this wasn't met with an increase in churn. I discussed this with Claude and we wrote a query joining renewal pairs to invoice counts and successor age in months. That confirmed a maturity bias: ACV was originally computed as cumulative invoiced-to-date, so a successor subscription only a couple of months old had far fewer invoices than the year-long original it was being compared against. This deflated GRR for any cohort whose successor started recently. I made the call to redefine ACV as an annualised run-rate (average invoice × 12) to remove this bias.

---

## 5. Identifying the accounts behind the GRR dips

Used to trace the three lowest-GRR periods (Oct 2025 Enterprise, Dec 2025 Mid-Market, Apr 2026 SMB) back to specific churned accounts (Verdant Holdings, Manuka Group, Quartz Trading) for the CS deck recommendations.

---

## 7. Building the CS-facing deck

Used to scope and generate the 2-slide deck (`grr_insights_deck.pptx`) per the brief's structure, then applied a styling preferences

---