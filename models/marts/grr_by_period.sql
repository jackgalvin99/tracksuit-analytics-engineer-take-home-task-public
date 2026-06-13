with renewals as (

    select
        r.subscription_id,
        r.account_id,
        a.size_grouped,
        r.end_date,
        date_trunc('month', r.end_date) as period_month,
        r.outcome,
        r.original_acv,
        r.retained_acv

    from {{ ref('fct_subscription_renewals') }} r
    left join {{ ref('dim_accounts') }} a
        on r.account_id = a.account_id
    where r.outcome in ('renewed', 'churned')
      and r.end_date >= date_trunc('month', current_date) - interval '11 months'

)

select
    period_month,
    size_grouped,
    count(*) as subscriptions_up_for_renewal,
    sum(case when outcome = 'churned' then 1 else 0 end) as subscriptions_churned,
    sum(original_acv) as starting_acv,
    sum(retained_acv) as retained_acv,
    sum(retained_acv) / nullif(sum(original_acv), 0) as gross_revenue_retention

from renewals
group by 1, 2
order by 1, 2