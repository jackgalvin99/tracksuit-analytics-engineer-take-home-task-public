with accounts as (

    select * from {{ ref('stg_subskribe__accounts') }}

),

bridge as (

    select * from {{ ref('bdg_hubspot__company_ids') }}

),

companies as (

    select * from {{ ref('stg_hubspot__companies') }}

),

resolved as (

    select
        a.account_id,
        a.company_name as subskribe_company_name,
        a.crmid,
        a.currency,
        a.created_at as account_created_at,
        b.company_id as hubspot_company_id

    from accounts a
    left join bridge b on a.crmid = b.merged_object_id

)

select
    r.account_id,
    r.subskribe_company_name,
    r.crmid,
    r.hubspot_company_id,
    c.company_name as hubspot_company_name,
    c.industry,
    c.size_grouped,
    c.country,
    r.currency,
    r.account_created_at,
    (r.hubspot_company_id is not null) as has_hubspot_match

from resolved r
left join companies c on r.hubspot_company_id = c.company_id