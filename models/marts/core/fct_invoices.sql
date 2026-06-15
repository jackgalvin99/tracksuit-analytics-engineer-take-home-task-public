with invoices as (

    select * from {{ ref('stg_subskribe_invoices') }}

),

final as (

     select
        invoice_id,
        account_id,
        subscription_id,
        invoice_date,
        cast(strftime(invoice_date, '%Y%m%d') as integer) as invoice_date_key,
        status,
        currency,
        total,
        total_nzd

    from invoices

)

select * from final
