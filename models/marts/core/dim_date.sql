with spine as (

    select unnest(generate_series(
        cast('2023-01-01' as date),
        cast('2027-12-31' as date),
        interval '1 day'
    )) as date_day

)

select
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
    date_day,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    extract(month from date_day) as month,
    strftime(date_day, '%B') as month_name,
    extract(day from date_day) as day_of_month,
    extract(dow from date_day) as day_of_week,
    strftime(date_day, '%A') as day_name,
    'Q' || cast(extract(quarter from date_day) as varchar)
        || ' ' || cast(extract(year from date_day) as varchar) as year_quarter

from spine