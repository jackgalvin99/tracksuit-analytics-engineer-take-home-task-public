with subs as (

	select * from {{ ref('int_subscriptions_acv') }}

),

successors as (

	select
		renewed_from_subscription_id as subscription_id,
		subscription_id as successor_subscription_id,
		acv_nzd as successor_acv

	from subs
	where renewed_from_subscription_id is not null

),

final as (

	select
		s.subscription_id,
		s.account_id,
		s.renewed_from_subscription_id,
		s.end_date,
		s.acv_nzd as original_acv,
		succ.successor_acv,
		case
			when succ.successor_subscription_id is not null then least(s.acv_nzd, succ.successor_acv)
			when s.subscription_state = 'ACTIVE' then null
			else 0
		end as retained_acv,
		case
			when succ.successor_subscription_id is not null then 'renewed'
			when s.subscription_state = 'ACTIVE' then 'in-progress'
			else 'churned'
		end as outcome

	from subs s
	left join successors succ on s.subscription_id = succ.subscription_id

)

select * from final
