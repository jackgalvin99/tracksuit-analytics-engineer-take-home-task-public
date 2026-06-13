with source as (

    select * from {{ source('subskribe', 'subscriptions') }}

),

final as (

    select
        subscription_id,
        account_id,
        subscription_state,
        start_date::date as start_date,
        end_date::date as end_date,
        cancelled_date::date as cancelled_date,
        renewed_from_subscription_id,
        creation_time::timestamp as created_at_timestamp,
        updated_at::timestamp as updated_at_timestamp

    from source

)

select * from final