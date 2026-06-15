with renewals as (

    select * from {{ ref('int_subscriptions_renewals') }}

),

final as (

     select
        subscription_id,
        account_id,
        renewed_from_subscription_id,
        end_date,
        outcome,
        original_acv,
        successor_acv,
        retained_acv

    from renewals

)

select * from final