with source as (

    select * from {{ source('subskribe', 'invoices') }}

),

renamed as (

    select
        invoice_id,
        account_id,
        subscription_id,
        invoice_date::date as invoice_date,
        total,
        total_nzd,
        currency,
        status

    from source

)

select * from renamed