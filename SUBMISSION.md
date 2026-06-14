# Submission Notes

## Run Instructions

1. Install dependencies: `dbt deps` (dbt utils package is used) and ensure `dbt-duckdb` is installed.
2. Profile setup (`profiles.yml`):
```yaml
   tracksuit_take_home:
     target: dev
     outputs:
       dev:
         type: duckdb
         path: tracksuit.duckdb
         schema: analytics
         threads: 4
```
3. Build the project: `dbt build` (runs models + tests). All models materialize into the `analytics` schema; raw source tables sit in `raw`.
4. To inspect the GRR output directly:
```sql
   select * from analytics.rpt_grr_by_period order by period_month, size_grouped;
```

---

## Headline Result

Blended trailing-12-month GRR (Jul 2025 - May 2026) averages ~96%, indicating healthy overall retention. Three monthly dips stand out:

| Period | Segment | GRR | Driver |
|---|---|---|---|
| Oct 2025 | Enterprise | 77.5% | Verdant Holdings (AU, Technology) churned, $61.8k ACV |
| Dec 2025 | Mid-Market | 80.0% | Manuka Group (NZ, Consumer Goods) churned, $24.9k ACV |
| Apr 2026 | SMB | 64.7% | Quartz Trading (US, Health & Beauty) churned, $10.2k ACV |

Each dip is driven by a single churned account in a small cohort (1-7 subscriptions per segment/month); a concentration-risk pattern rather than a systemic retention issue. See the accompanying deck for CS recommendations.

---

## Metric Definition: GRR

GRR is implemented via a renewal-chain model rather than a point-in-time revenue comparison:

- `int_subscriptions__renewals` walks the `renewed_from_subscription_id` chain to pair each subscription with its successor (if any).
- For a pair, the **original** subscription represents the cohort's revenue at month M-12, and the **successor** represents that same cohort's revenue at month M.
- `retained_acv = least(original_acv, successor_acv)` implements the brief's "gross" requirement, any expansion in the successor is capped at the original amount, so upsells don't inflate retention.
- `outcome` is derived per subscription:
  - `renewed`: has a successor subscription
  - `churned`: no successor, and the subscription has ended (EXPIRED/CANCELED)
  - `in-progress`: no successor yet, subscription still ACTIVE
- `fct_subscription_renewals` exposes one row per subscription with `original_acv`, `successor_acv`, `retained_acv`, `outcome`, and the account/segment attributes needed for slicing.
- `rpt_grr_by_period` aggregates to `period_month` (the original subscription's end month, i.e. month M) and `size_grouped`, filtering to `outcome in ('renewed', 'churned')`:
```
  GRR = sum(retained_acv) / sum(original_acv)
```
  This matches the brief's definition exactly: cohort fixed at M-12, GRR for month M = retained revenue from that cohort at M, divided by the cohort's revenue at M-12.

---

## Metric Definition: ACV

`int_subscriptions__acv` computes ACV as an **annualised run-rate**, not cumulative invoiced revenue to date:

```sql
acv_nzd = (
  sum(case when status != 'VOIDED' then total_nzd else 0 end)
  / nullif(count(case when status != 'VOIDED' then 1 end), 0)
) * 12
```

That is: average non-voided invoice amount × 12. Two decisions sit behind this:

1. **Cumulative-to-date ACV creates a maturity bias.** Subscriptions are billed monthly, so a subscription's total invoiced amount grows with its age. When computing GRR for a renewal pair, the *successor* subscription is almost always younger than the original. A successor that started 2 months ago has ~2 invoices, while the original (a full prior term) has ~12-13. Using cumulative totals therefore systematically understates `successor_acv` relative to `original_acv`, dragging GRR down toward 0% for the most recent months regardless of actual retention. The annualised run-rate removes this bias by normalizing for how many invoices have actually been billed so far.
2. **VOIDED invoices (113 of 3,594) are excluded** from the average. They represent cancelled billing amounts, not revenue. There was no matching reissue to net them against.

This fix changed the trailing-12-month GRR profile from a misleading decline toward 0% in recent months to a stable ~94-100% baseline with three explainable dips (see Headline Result above).

---

## Key Assumptions / Decisions

- **ACV basis**: annualised run-rate (avg non-voided invoice × 12), not cumulative invoiced-to-date (see Metric Definition: ACV).
- **Granularity**: GRR is computed at the subscription level via the renewal chain. This is equivalent to account-level for this dataset, since each account holds at most one active subscription at a time.
- **Single-subscription CANCELED accounts** (6 accounts, cancelled within their first term, never renewed): treated as `outcome = 'churned'` with `retained_acv = 0`. This is a deliberate choice. These are early churns and should count as full revenue loss in the cohort they belong to.
- **ACTIVE subscriptions with no successor yet** (111 currently-active subs): treated as `outcome = 'in-progress'` and excluded from `rpt_grr_by_period`. GRR measures *completed* renewal decisions (renewed or churned); an in-progress subscription hasn't reached its renewal point yet, so including it would mix incomplete cohorts into the metric.
- **Mid-chain CANCELED subscriptions** (5 accounts) follow the same renewal-chain logic as any other subscription (they simply have no successor and resolve to `outcome = 'churned'`).

---

## Data Profiling

### hubspot_companies (120 rows)
- `company_id` is unique (120 distinct), PK.
- No nulls in `company_id`, `company_name`, `size_grouped`, `industry`, `country`, `created_at`.
- `merged_object_ids`: 106 blank, 14 populated. Where populated, it's one or more `hsold_...` IDs separated by `;` (no other formats).
- `size_grouped`: 4 values (SMB, Mid-Market, Startup, Enterprise).
- `country`: 4 values (US, AU, GB, NZ).
- `industry`: 10 distinct values.
- `created_at`: dates range 2023-05-25 to 2024-07-16, no nulls.
- No duplicate `company_name`.

### subskribe_accounts (122 rows)
- `account_id` and `crmid` both unique and non-null.
- `crmid` breaks into three patterns: 109 `hs_...` (canonical HubSpot company IDs), 11 `hsold_...` (merged/historical IDs), 2 `hsmissing_...`.
- All 11 `hsold_` values match exactly one entry in `hubspot_companies.merged_object_ids`: so a bridge table resolves cleanly: each `hsold_` ID maps to exactly one canonical `hs_` company.
- 109 + 11 = 120, which equals the total HubSpot company count, so every HubSpot company has exactly one corresponding subskribe account, either directly or via the merge bridge. Clean 1:1 once resolved.
- The 2 `hsmissing_` rows (Wrenfield Brewing, Riverbend Co) don't match any `company_id` or any `merged_object_ids` entry in HubSpot at all, i.e. orphaned accounts with no CRM company record (data quality issue, see Data Quality Notes below).
- `company_name` contains duplicates. 11 names are duplicated (mostly generic "X Pty" placeholders covering multiple distinct accounts/companies), and names often don't match the HubSpot `company_name` for the same `crmid` (e.g. "Silverpine Pty" here vs "Silverpine Trading"/"Pet Co"/"Holdings" in HubSpot). `crmid` is the only safe join key.
- `currency`: 4 values (USD 38, AUD 32, GBP 27, NZD 25), no nulls.
- `created_at`: 2023-06-06 to 2024-09-10, no nulls.

### subskribe_subscriptions (330 rows)
- `subscription_id` is a clean PK; 122 distinct `account_id` (matches accounts table exactly, full join integrity both ways).
- States: 208 EXPIRED, 111 ACTIVE, 11 CANCELED.
- 92 accounts have 3-subscription chains (EXPIRED → EXPIRED → ACTIVE, ~annual renewal), 24 have 2, 6 have just 1.
- All 6 single-subscription accounts are CANCELED. These are early churns (created and cancelled within their first term, no renewal ever started).
- `renewed_from_subscription_id`: 100% referential integrity, no broken links (clean renewal chains).
- 11 CANCELED subscriptions total: the 6 single-sub accounts above, plus 5 mid-chain cancellations (`sub_a5614ebe48f8df0f`, `sub_f86dc17c9a57d565`, `sub_eb281f8b0cb35107`, `sub_75d50635e17f9275`, `sub_c5bab7fe7a6ba65b`, `sub_c098b07d05efaf05`). For every non-CANCELED account, the latest subscription (by `end_date`) is ACTIVE. "latest sub state" cleanly identifies churned vs retained accounts.
- `cancelled_date` populated only for the 11 CANCELED rows (319 nulls), as expected.
- Date range: 2023-06-10 to 2027-05-18.

### subskribe_invoices (3,594 rows)
- `invoice_id` clean PK. 100% FK integrity to both subscriptions and accounts, and `account_id` on the invoice always matches the `account_id` on its subscription (no cross-account leakage).
- Status: 3,321 PAID, 160 POSTED, 113 VOIDED.
- Currency: USD 1,072 / AUD 1,018 / GBP 800 / NZD 704. `total_nzd` equals `total` only for NZD rows; everything else has a converted `total_nzd ≠ total`, confirming `total_nzd` is the consistent reporting currency.
- Invoices per subscription: 210 of 330 subscriptions have exactly 13 (monthly billing over a ~1yr term, 12 + a likely proration/final invoice); the rest taper down for partial-term subscriptions (CANCELED/short chains).
- Date range: 2023-06-03 to 2026-05-06. POSTED invoices span the full range too (not just future-dated), worth noting if "unpaid/outstanding" matters for revenue logic.
- VOIDED invoices (113): checked for a matching same-subscription/same-date reissue and found none. So these are pure cancellations of billed amounts, not "voided + reissued" pairs. These were handled explicitly by excluding them from the ACV calculation (see Metric Definition: ACV).

---

## Data Quality Notes

### Orphaned `hsmissing_` accounts

Two `subskribe_accounts` rows (Wrenfield Brewing, Riverbend Co) have `crmid` values starting `hsmissing_` that don't match any `hubspot_companies.company_id` or `merged_object_ids` entry. These accounts have no corresponding CRM company record.

Resolution: `dim_accounts` coalesces `size_grouped`, `industry`, and `country` to `'Unknown'` for these two accounts rather than dropping them or defaulting to a real segment value (which would misrepresent them). They surface in `rpt_grr_by_period` as their own `'Unknown'` segment rows (2025-09 and 2026-04, both GRR = 1.0, i.e. single-subscription cohorts with no churn), so they don't distort the named segments but remain visible for follow-up (e.g. fixing the CRM link).

### VOIDED invoices

113 of 3,594 invoices are VOIDED, with no matching reissue found for any of them. These are excluded from ACV calculations as cancelled billing amounts rather than revenue (see Metric Definition: ACV).

---

## Things I Would Have Liked to Consider

- Add sqlfluff to the project.
- Add a docs section, where definitions can be reused across models.
- Add CI checks, e.g. mandatory PK tests.
- Add more tests e.g. unit tests.
- Put together more sophisticated analysis for churn, potentially in the form of a dashboard, where there is functionality to split by many different dimensions.
- Define a metric for a customer that is 'at risk of churn', i.e. a leading indicator for a customer that may churn in 3-6 months, for example.