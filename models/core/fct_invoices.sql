with invoices as (

    select * from {{ ref('stg_subskribe__invoices') }}

)

select
    invoice_id,
    account_id,
    subscription_id,
    invoice_date,
    status,
    currency,
    total,
    total_nzd

from invoices