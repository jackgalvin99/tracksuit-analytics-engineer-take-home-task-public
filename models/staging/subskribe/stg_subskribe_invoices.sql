with source as (

    select * from {{ source('subskribe', 'invoices') }}

),

final as (

    select
        invoice_id,
        account_id,
        subscription_id,
        cast(invoice_date as date) as invoice_date,
        total,
        total_nzd,
        currency,
        status

    from source

)

select * from final
