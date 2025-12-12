--Task 1
-- top 5 customers by amount_sold in each channel
-- approach:
-- 1) aggregate customer sales per channel
-- 2) compute each customer's share within the channel using a window sum
-- 3) rank customers per channel with row_number() (no window FRAME is used)
-- 4) keep only top 5 per channel and format amounts/percentages

with customer_sales as (
    -- step 1: total sales per customer per channel
    select
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name,
        sum(s.amount_sold) as amount_sold,
        -- step 2: customer's share of total channel sales (0–1)
        sum(s.amount_sold)
            / sum(sum(s.amount_sold)) over (partition by ch.channel_desc)
            as sales_ratio
    from channels   ch
    join sales      s  on s.channel_id = ch.channel_id
    join customers  c  on c.cust_id    = s.cust_id
    group by
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name
),
ranked_sales as (
    select
        channel_desc,
        cust_last_name,
        cust_first_name,
        -- amount with 2 decimal places
        round(amount_sold, 2) as amount_sold,
        -- step 3: sales percentage with 4 decimals + '%' sign
        to_char(round(sales_ratio * 100, 4), 'fm9999990.0000') || ' %'
            as sales_percentage,
        row_number() over (
            partition by channel_desc
            order by amount_sold desc
        ) as rn
    from customer_sales
)
select
    channel_desc,
    cust_last_name,
    cust_first_name,
    amount_sold,
    sales_percentage
from ranked_sales
where rn <= 5
order by
    channel_desc,
    amount_sold desc;

--Task 2: total sales per Photo product in Asia in year 2000,
-- split by quarters and with YEAR_SUM column

set search_path to sh, public;

select
    p.prod_name                                           as product_name,
    round(sum(case when t.calendar_quarter_number = 1
                   then s.amount_sold else 0 end), 2)     as q1,
    round(sum(case when t.calendar_quarter_number = 2
                   then s.amount_sold else 0 end), 2)     as q2,
    round(sum(case when t.calendar_quarter_number = 3
                   then s.amount_sold else 0 end), 2)     as q3,
    round(sum(case when t.calendar_quarter_number = 4
                   then s.amount_sold else 0 end), 2)     as q4,
    round(sum(s.amount_sold), 2)                          as year_sum
from sales     s
join products  p  on s.prod_id   = p.prod_id
join customers c  on s.cust_id   = c.cust_id
join countries co on c.country_id = co.country_id
join times     t  on s.time_id   = t.time_id
where p.prod_category   = 'Photo'
  and co.country_region = 'Asia'
  and t.calendar_year   = 2000
group by
    p.prod_name
order by
    year_sum desc,
    p.prod_name;

-- Task 3: top 300 customers per channel (years 1998, 1999, 2001)
-- approach:
--   1) aggregate total sales per customer within each sales channel
--      for years 1998, 1999 and 2001
--   2) rank customers per channel by total sales using row_number()
--      (no window FRAME clause)
--   3) keep only top 300 per channel and format amount_sold

set search_path to sh, public;

with customer_channel_sales as (
    -- step 1: total sales per customer per channel
    select
        ch.channel_desc,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name,
        sum(s.amount_sold) as amount_sold
    from sales     s
    join customers c  on s.cust_id    = c.cust_id
    join channels  ch on s.channel_id = ch.channel_id
    join times     t  on s.time_id    = t.time_id
    where t.calendar_year in (1998, 1999, 2001)
    group by
        ch.channel_desc,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name
),
ranked_sales as (
    -- step 2: rank customers within each channel by total sales
    select
        channel_desc,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold,
        row_number() over (
            partition by channel_desc
            order by amount_sold desc
        ) as rn
    from customer_channel_sales
)
-- step 3: select only top 300 per channel and format amount_sold
select
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name,
    round(amount_sold::numeric, 2) as amount_sold
from ranked_sales
where rn <= 300
order by
    channel_desc,
    amount_sold desc,
    cust_last_name,
    cust_first_name;

--Task 4
set search_path to sh, public;

select
    t.calendar_month_desc,
    p.prod_category,
    -- total sales for Americas
    round(
        sum(
            case
                when co.country_region = 'Americas'
                then s.amount_sold
                else 0
            end
        ), 2
    ) as americas_sales,
    -- total sales for Europe
    round(
        sum(
            case
                when co.country_region = 'Europe'
                then s.amount_sold
                else 0
            end
        ), 2
    ) as europe_sales
from sales     s
join customers c  on s.cust_id    = c.cust_id
join countries co on c.country_id = co.country_id
join times     t  on s.time_id    = t.time_id
join products  p  on s.prod_id    = p.prod_id
where t.calendar_year = 2000
  and t.calendar_month_number in (1, 2, 3)              -- Jan, Feb, Mar 2000
  and co.country_region in ('Europe', 'Americas')       -- only these regions
group by
    t.calendar_month_desc,
    p.prod_category
order by
    t.calendar_month_desc,
    p.prod_category;


