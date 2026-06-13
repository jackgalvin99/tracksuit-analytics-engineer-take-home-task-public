with source as (

    select * from {{ source('subskribe', 'accounts') }}

),

final as (

    select
        account_id,
        company_name,
        crmid,
        currency,
        cast(created_at as timestamp) as created_at

    from source

)

select * from final