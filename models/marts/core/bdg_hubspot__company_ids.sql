with companies as (

	select * from {{ ref('stg_hubspot__companies') }}

),

split_ids as (

	select
		company_id,
		trim(unnest(regexp_split_to_array(coalesce(merged_object_ids, ''), '[;,]'))) as merged_object_id

	from companies

),

final as (

	select distinct
		company_id,
		merged_object_id

	from split_ids
	where merged_object_id <> ''

	union all

	select
		company_id,
		company_id as merged_object_id

	from companies

)

select * from final
