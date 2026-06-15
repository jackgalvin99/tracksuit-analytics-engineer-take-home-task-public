with source as (

    select * from {{ source('subskribe', 'subscriptions') }}

),

final as (

    select
        subscription_id,
        account_id,
        subscription_state,
        cast(start_date as date) as start_date,
        cast(end_date as date) as end_date,
        cast(cancelled_date as date) as cancelled_date,
        renewed_from_subscription_id,
        cast(creation_time as timestamp) as creation_time,
        cast(updated_at as timestamp) as updated_at

    from source

)

select * from final
