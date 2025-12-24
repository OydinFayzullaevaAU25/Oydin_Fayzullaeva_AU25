--Task 1
-- top 5 customers by amount_sold in each channel
set search_path to sh, public;
select * from channels;
select * from sales;
with base_sales as (
    select
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name,
        sum(s.amount_sold) as amount_sold
    from channels ch
    join sales s on s.channel_id = ch.channel_id
    join customers c on c.cust_id = s.cust_id
    group by
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name
),
customer_sales as (
    select
        *,
        amount_sold
        / sum(amount_sold) over (partition by channel_desc) as sales_ratio
    from base_sales
),
ranked_sales as (
    select
        channel_desc,
        cust_last_name,
        cust_first_name,
        round(amount_sold, 2) as amount_sold,
        to_char(round(sales_ratio * 100, 4), 'fm9999990.0000') || ' %' as sales_percentage,
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

--Task 2: total sales per Photo product in Asia in year 2000

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


set search_path to sh, public;

with category_min_products as (
    select
        p.prod_category,
        p.prod_id,
        p.prod_name,
        p.prod_list_price,
        row_number() over (
            partition by p.prod_category
            order by p.prod_list_price, p.prod_id
        ) as rn_in_category
    from sales s
    join times t
        on t.time_id = s.time_id
    join products p
        on p.prod_id = s.prod_id
    where t.calendar_year = 2001
),
least_per_category as (
    select
        prod_category,
        prod_id,
        prod_name,
        prod_list_price
    from category_min_products
    where rn_in_category = 1
),
ranked_across_categories as (
    select
        prod_category,
        prod_name,
        prod_list_price,
        row_number() over (
            order by prod_list_price, prod_category, prod_id
        ) as pos
    from least_per_category
)
select
    prod_category,
    prod_name,
    prod_list_price,
    pos
from ranked_across_categories
where pos = 3;

select * from channels;
select * from customers;
select * from sales;
set search_path to sh, public;

--11
with customer_channel_sales as( 
     select 
     ch.channel_desc,
     c.cust_id,
  	 c.cust_last_name,		  
     c. cust_first_name,
  	 sum(s.amount_sold) as amount_sold  
  	 from sales s
  	 join customers c on c.cust_id=s.cust_id
  	 join channels ch on ch.channel_id=s.channel_id
  	 group by ch.channel_desc,
  	          c.cust_id,
  	          c.cust_last_name,
  	          c.cust_first_name
  	          ),
  	          ranked as ( select 
  	          *, 
  	          row_number () over (partition by channel_desc order by amount_sold desc) as rn
  	          from customer_channel_sales
  	          )
  	          select 
  	          channel_desc,
  	          cust_id,
  	          cust_last_name,
  	          cust_first_name,
  	          round (amount_sold, 2) as amount_sold
  	          from ranked
  	          where rn <= 5
  	          order by channel_desc, amount_sold desc;
--22
with category_sales as (
select 
p.prod_category,
sum(s.amount_sold) as amount_sold
from sales s
join products p on p.prod_id=s.prod_id
join times t on t.time_id=s.time_id
where t.calendar_year = 2000
group by p.prod_category
)
select 
prod_category,
round(amount_sold, 2) as amount_sold,
to_char(
	100 * amount_sold/ sum(amount_sold) over (), 'fm999990.0000'
	) || '%' as sales_percentage
	from category_sales 
	order by amount_sold desc;

--3.
 with ranked as ( 
 select 
 p.prod_category,
 p.prod_id,
 p.prod_name, 
 p.prod_list_price,
 dense_rank () over (partition by p.prod_category order by p.prod_list_price desc 
 )  as dr
 from products p)
 select
 prod_category,
 prod_name,
 prod_id,
 prod_list_price,
 dr as price_rank
 from ranked
 where dr <=  3
 order by prod_category,
 prod_name,
 prod_id,
 prod_list_price desc;

with monthly as (
	select
	ch.channel_desc,
	t.calendar_year,
	t.calendar_month_number,
	t.calendar_month_desc,
	sum(s.amount_sold) as month_sales
	from sales s
	join channels ch on ch.channel_id=s.channel_id
	join times t on t.time_id=s.time_id
	where t.calendar_year = 2000
	group by 
	ch.channel_desc,
	t.calendar_year,
	t.calendar_month_number,
	t.calendar_month_desc
	)
select 
channel_desc,
calendar_month_desc,
round (month_sales, 2) as month_sales,
round (lag(month_sales) over (partition by channel_desc order by calendar_month_number), 2) as diff_vs_prev_month
from monthly
order by channel_desc, calendar_month_number;
--Task 5
	 with ranked as (
	 select 
	 p.prod_category,
	 p.prod_name,
	 P.prod_id,
	 p.prod_list_price,
	 row_number() over (partition by p.prod_category order by p.prod_list_price asc, p.prod_id
	 ) as rn 
	 from products p
	 )
	 select 
	 prod_category,
	 prod_id,
	 prod_name,
	 prod_list_price
	 from ranked
	 where rn = 3
	 order by prod_category;

select * from sales;
	 
	select * from channels;
	
	
	
	select * from times;

	select 
	ch.channel_desc,
	c.cust_last_name,
	sum(s.amount_sold)as amount_sold,
	row_number () over (partition by ch.channel_desc order by sum (s.amount_sold) desc) as rn
	from sales s
	join channels ch on s.channel_id=ch.channel_id
	join customers c on s.cust_id=c.cust_id
	group by ch.channel_desc, c.cust_last_name;
	
	select *
	from ( 
	 select p.prod_category,
	 p.prod_name,
	 sum (s.amount_sold) as total_sales,
	 dense_rank () over (partition by p.prod_category order by sum (s.amount_sold) desc) as rnk
	 from sales s
	 join products p on p.prod_id=s.prod_id
	 group by p.prod_category, p.prod_name) t 
	 where rnk<=3;
	
	create or replace function get_fixed_number ()
	returns integer
	language plpgsql
	as $$
	begin
		return 10;
	end;
	$$;
	
	select get_fixed_number();
	
	create or replace function total_sales_for_customer (p_customer text)
	returns int
	language sql
	as $$
	select sum(amount)
	from sales_small
	where customer=p.customer;
	$$;
	
	select c.channel_id,
	c.channel_desc,
	sum(s.amount_sold) as total_sales,
	rank() over (order by sum(s.amount_sold) desc) as sales_rank
	from sh.sales s 
	join sh.channels c
	on s.channel_id=c.channel_id
	group by c.channel_id, c.channel_desc
	order by sales_rank;

select * from sales;

with q_sales as (
    select
        t.calendar_quarter_number as qtr,
        sum(s.amount_sold) as sales_amt
    from sh.sales s
    join sh.times t
      on t.time_id = s.time_id
    join sh.products p
      on p.prod_id = s.prod_id
    join sh.channels ch
      on ch.channel_id = s.channel_id
    where p.prod_category = 'Hardware'
      and ch.channel_desc in ('Partners', 'Internet')
      and t.calendar_year = 2000
      and t.calendar_quarter_number in (1, 4)
    group by t.calendar_quarter_number
),
pivoted as (
    select
        max(case when qtr = 1 then sales_amt end) as q1_sales,
        max(case when qtr = 4 then sales_amt end) as q4_sales
    from q_sales
)
select
    q1_sales,
    q4_sales,
    round(((q4_sales - q1_sales) / nullif(q1_sales, 0)) * 100.0, 2) as pct_difference_q4_vs_q1
from pivoted;

select
    sum(s.amount_sold) as total_sales_2000
from sh.sales s
join sh.times t
  on t.time_id = s.time_id
join sh.products p
  on p.prod_id = s.prod_id
join sh.channels ch
  on ch.channel_id = s.channel_id
where t.calendar_year = 2000
  and t.calendar_quarter_number in (1, 2, 3, 4)
  and ch.channel_desc in ('Partners', 'Internet')
  and p.prod_category in ('Electronics', 'Hardware', 'Software/Other');

