--Task 1
with sales_by_channel as (
    select
        co.country_region,
        t.calendar_year,
        ch.channel_desc,
        sum(s.amount_sold) as amount_sold
    from sh.sales s
    join sh.times t
      on t.time_id = s.time_id
    join sh.customers cu
      on cu.cust_id = s.cust_id
    join sh.countries co
      on co.country_id = cu.country_id
    join sh.channels ch
      on ch.channel_id = s.channel_id
    where t.calendar_year between 1999 and 2001
      and co.country_region in ('Americas', 'Asia', 'Europe')
    group by
        co.country_region,
        t.calendar_year,
        ch.channel_desc
),
pct_calc as (
    select
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        round(
            amount_sold
            / nullif(sum(amount_sold) over (partition by country_region, calendar_year), 0)
            * 100.0,
            2
        ) as pct_by_channels
    from sales_by_channel
),
final as (
    select
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        pct_by_channels,
        lag(pct_by_channels) over (
            partition by country_region, channel_desc
            order by calendar_year
        ) as pct_previous_period
    from pct_calc
)
select
    country_region,
    calendar_year,
    channel_desc,
    amount_sold,
    pct_by_channels as "% by channels",
    round(pct_previous_period, 2) as "% previous period",
    round(pct_by_channels - pct_previous_period, 2) as "% diff"
from final
order by
    country_region,
    calendar_year,
    channel_desc;

--Task 2
set search_path to sh, public;

with daily_sales as (
    select
        t.calendar_year,
        t.calendar_week_number as week,
        t.time_id::date as calendar_date,
        t.day_name,
        sum(s.amount_sold) as amount_sold
    from sh.sales s
    join sh.times t
      on t.time_id = s.time_id
    where t.calendar_year = 1999
      and t.calendar_week_number in (49, 50, 51)
    group by
        t.calendar_year,
        t.calendar_week_number,
        t.time_id::date,
        t.day_name
),
windowed as (
    select
        calendar_year,
        week,
        calendar_date,
        day_name,
        amount_sold,

        sum(amount_sold) over (
            partition by calendar_year, week
            order by calendar_date
            rows between unbounded preceding and current row
        ) as cum_sum,

        lag(amount_sold, 2) over (order by calendar_date) as prev2_day,
        lag(amount_sold, 1) over (order by calendar_date) as prev_day,
        lead(amount_sold, 1) over (order by calendar_date) as next_day,
        lead(amount_sold, 2) over (order by calendar_date) as next2_day
    from daily_sales
)
select
    week as calendar_week_number,
    calendar_date as time_id,
    day_name,
    amount_sold,
    round(cum_sum, 2) as cum_sum,
    round(
        case
            when day_name = 'Monday'
                then (prev2_day + prev_day + amount_sold + next_day) / 4.0
            when day_name = 'Friday'
                then (prev_day + amount_sold + next_day + next2_day) / 4.0
            else
                (prev_day + amount_sold + next_day) / 3.0
        end,
        2
    ) as centered_3_day_avg
from windowed
order by
    calendar_date;

--Task 3

-- EXAMPLE 1: ROWS
-- Purpose: cumulative daily sales inside each calendar week
-- Reason for ROWS:
--   ROWS is position-based and guarantees that exactly
--   the current row and all previous rows in order are included.
--   This is required for a true running total.        
select
    t.calendar_week_number,
    t.time_id::date as calendar_date,
    sum(s.amount_sold) as daily_sales,

    sum(sum(s.amount_sold)) over (
        partition by t.calendar_week_number
        order by t.time_id
        rows between unbounded preceding and current row
    ) as cumulative_week_sales
from sh.sales s
join sh.times t
  on t.time_id = s.time_id
where t.calendar_year = 1999
group by
    t.calendar_week_number,
    t.time_id
order by
    t.calendar_week_number,
    calendar_date;

-- EXAMPLE 2: RANGE
-- Purpose: 7-day rolling average of sales
-- Reason for RANGE:
--   RANGE is value-based (date interval), not row-count-based.
--   This ensures the window always represents 7 calendar days
--   even if some dates are missing.

select
    t.time_id::date as calendar_date,
    sum(s.amount_sold) as daily_sales,

    avg(sum(s.amount_sold)) over (
        order by t.time_id
        range between interval '6 days' preceding and current row
    ) as rolling_7_day_avg
from sh.sales s
join sh.times t
  on t.time_id = s.time_id
where t.calendar_year = 1999
group by
    t.time_id
order by
    calendar_date;

-- EXAMPLE 3: GROUPS
-- Purpose: average sales per channel across the current
--          and neighboring channels (logical groups)
-- Reason for GROUPS:
--   GROUPS operates on peer groups defined by ORDER BY,
--   not individual rows. This is ideal when analysis

select
    ch.channel_desc,
    sum(s.amount_sold) as channel_sales,

    avg(sum(s.amount_sold)) over (
        order by ch.channel_desc
        groups between 1 preceding and 1 following
    ) as avg_neighbor_channel_sales
from sh.sales s
join sh.channels ch
  on ch.channel_id = s.channel_id
group by
    ch.channel_desc
order by
    ch.channel_desc;

        