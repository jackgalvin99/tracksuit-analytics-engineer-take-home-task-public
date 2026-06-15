with source as (

    select * from {{ source('hubspot', 'companies') }}

),

final as (

    select
        company_id,
        company_name,
        size_grouped,
        industry,
        country,
        merged_object_ids,
        cast(created_at as date) as created_at

    from source

)

select * from final
