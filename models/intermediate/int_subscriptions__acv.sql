with subscriptions as (

	select * from {{ ref('stg_subskribe__subscriptions') }}

),

invoices as (

	select * from {{ ref('stg_subskribe__invoices') }}

),

acv as (

	select
		subscription_id,
		sum(
			case
				when status != 'VOIDED' then cast(total_nzd as decimal(18,3))
				else cast(0 as decimal(18,3))
			end
		) as acv_nzd

	from invoices
	group by 1

)

select
	s.subscription_id,
	s.account_id,
	s.subscription_state,
	s.start_date,
	s.end_date,
	s.cancelled_date,
	s.renewed_from_subscription_id,
	s.creation_time,
	s.updated_at,
	coalesce(a.acv_nzd, 0) as acv_nzd

from subscriptions s
left join acv a on s.subscription_id = a.subscription_id
