--Task1. Create a view

create or replace view sales_revenue_by_category_qtr as
with current_period as (
select
date_trunc('quarter', current_date)::date                           as qtr_start,
(date_trunc('quarter', current_date) + interval '3 month')::date    as qtr_end,
extract(year from current_date)::int                                as sales_year,
extract(quarter from current_date)::int                             as sales_quarter
)
select
c.name               as category_name,
cp.sales_year        as year,
cp.sales_quarter     as quarter,
sum(p.amount)        as total_sales_revenue
from payment        p
join rental         r  on p.rental_id   = r.rental_id
join inventory      i  on r.inventory_id = i.inventory_id
join film           f  on i.film_id     = f.film_id
join film_category  fc on f.film_id     = fc.film_id
join category       c  on fc.category_id = c.category_id
cross join current_period cp
where p.payment_date >= cp.qtr_start
  and p.payment_date <  cp.qtr_end
group by
c.name,
cp.sales_year,
cp.sales_quarter
having sum(p.amount) > 0;

--Task 2. Create a query language functions

create or replace function get_sales_revenue_by_category_qtr(
    p_ref_date date default current_date
)
returns table (
    category_name text,
    year          int,
    quarter       int,
    total_sales_revenue numeric
)
language sql
stable
as
$$
with selected_period as (
    select
        date_trunc('quarter', p_ref_date)::date                        as qtr_start,
        (date_trunc('quarter', p_ref_date) + interval '3 month')::date as qtr_end,
        extract(year from p_ref_date)::int                             as sales_year,
        extract(quarter from p_ref_date)::int                          as sales_quarter
)
select
    c.name              as category_name,
    sp.sales_year       as year,
    sp.sales_quarter    as quarter,
    sum(p.amount)       as total_sales_revenue
from payment       p
join rental        r  on p.rental_id    = r.rental_id
join inventory     i  on r.inventory_id = i.inventory_id
join film          f  on i.film_id      = f.film_id
join film_category fc on f.film_id      = fc.film_id
join category      c  on fc.category_id = c.category_id
cross join selected_period sp
where p.payment_date >= sp.qtr_start
  and p.payment_date <  sp.qtr_end
group by
    c.name,
    sp.sales_year,
    sp.sales_quarter
having sum(p.amount) > 0;
$$;

--Task 3. Create procedure language function

create schema if not exists core;

create or replace function core.most_popular_films_by_countries(
    p_countries text[]
)
returns table (
    country       text,
    film          text,
    rating        text,
    language      text,
    length        smallint,   
    release_year  smallint    
)
language plpgsql
as
$$
begin
    if p_countries is null or array_length(p_countries, 1) is null then
        raise exception 'country list cannot be null or empty';
    end if;

    return query
    with rbcf as (
        select
            co.country::text          as country,
            f.title::text             as film,
            f.rating::text            as rating,
            l.name::text              as language,
            f.length::smallint        as length,        
            f.release_year::smallint  as release_year,  
            row_number() over (
                partition by co.country
                order by count(r.rental_id) desc
            )                        as rn
        from rental r
        join inventory i on r.inventory_id = i.inventory_id
        join film f      on i.film_id      = f.film_id
        join language l  on f.language_id  = l.language_id
        join customer cu on r.customer_id  = cu.customer_id
        join address a   on cu.address_id  = a.address_id
        join city ci     on a.city_id      = ci.city_id
        join country co  on ci.country_id  = co.country_id
        where co.country = any (p_countries)
        group by
            co.country,
            f.title,
            f.rating,
            l.name,
            f.length,
            f.release_year
    )
    select
        rbcf.country,
        rbcf.film,
        rbcf.rating,
        rbcf.language,
        rbcf.length,
        rbcf.release_year
    from rbcf
    where rbcf.rn = 1
    order by rbcf.country;

    if not found then
        raise exception 'no rentals found for given countries: %', p_countries;
    end if;
end;
$$;


select *
from core.most_popular_films_by_countries(
    array['Afghanistan', 'Brazil', 'United States']
);


--Task 4.

create or replace function core.films_in_stock_by_title(
    p_title_pattern text
)
returns table (
    row_num       integer,
    film_title    text,
    film_language text,
    customer_name text,
    rental_date   timestamp without time zone  
)
language plpgsql
as
$$
begin
    if p_title_pattern is null or length(p_title_pattern) = 0 then
        raise exception 'title pattern cannot be null or empty';
    end if;

    return query
    with available_inventory as (
        select
            i.inventory_id,
            f.title::text as film_title,
            l.name::text  as film_language
        from film f
        join language l on f.language_id = l.language_id
        join inventory i on f.film_id = i.film_id
        where f.title ilike p_title_pattern
          and not exists (
              select 1
              from rental r
              where r.inventory_id = i.inventory_id
                and r.return_date is null          -- copy is in stock
          )
    ),
    last_rentals as (
        select
            i.inventory_id,
            (c.first_name || ' ' || c.last_name)::text as customer_name,
            r.rental_date::timestamp without time zone as rental_date,  -- explicit cast
            row_number() over (
                partition by i.inventory_id
                order by r.rental_date desc
            ) as rn
        from inventory i
        join rental r   on r.inventory_id = i.inventory_id
        join customer c on c.customer_id  = r.customer_id
    )
    select
        row_number() over (order by ai.film_title, ai.inventory_id)::int as row_num,
        ai.film_title,
        ai.film_language,
        lr.customer_name,
        lr.rental_date
    from available_inventory ai
    left join last_rentals lr
           on ai.inventory_id = lr.inventory_id
          and lr.rn = 1
    order by row_num;

    if not found then
        raise exception 'no films in stock matching title pattern: %', p_title_pattern;
    end if;
end;
$$;


select *
from core.films_in_stock_by_title('%love%');

--Task 5  Create procedure language functions

create schema if not exists core;

create or replace function core.new_movie(
    p_title         text,
    p_release_year  smallint default null,
    p_language_name text    default null
)
returns integer
language plpgsql
as
$$
declare
    v_language_id  integer;
    v_release_year smallint;
    v_new_film_id  integer;
begin
    -- basic validation
    if p_title is null or length(trim(p_title)) = 0 then
        raise exception 'movie title cannot be null or empty';
    end if;

    -- default values
    v_release_year := coalesce(
        p_release_year,
        extract(year from current_date)::smallint
    );

    -- default language name is ''Klingon''
    p_language_name := coalesce(p_language_name, 'Klingon');

    -- verify language exists and get its id
    select l.language_id
    into v_language_id
    from public.language l
    where l.name = p_language_name;

    if not found then
        raise exception 'language "%" does not exist in language table', p_language_name;
    end if;

    -- insert new film
    insert into public.film (
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost
    )
    values (
        p_title,
        v_release_year,
        v_language_id,
        3,          
        4.99,      
        19.99      
    )
    returning film_id into v_new_film_id;

    -- return new film_id
    return v_new_film_id;
end;
$$;

insert into public.language(name) --beacause the task explicitly says that default language should be Klingon, and dvdrental database does not have this language, we should insert it first
values ('Klingon');

-- simplest: only title (current year, Klingon)
select core.new_movie('My Brand New Klingon Movie');

-- custom release year, default language = Klingon
select core.new_movie('Old Klingon Classic', 1995::smallint);

-- custom release year and language
select core.new_movie('French Romance', 2001::smallint, 'French');

--Task 6.

/*
Task 6.
1.	
film_in_stock (film_id, stock_id) returns a set of inventory_id values.
This function shows which specific physical copies of a film are currently in stock (not rented or lost) at a given store.
The function works by checking inventory , rental, and rental return dates to ensure the film is available.
film_not_in_stock(film_id,store_id) returns a set of inventory_id values.
The function shows copies of the film that are not available (because they are rented, lost, or otherwise unavailable).
The function works as the logical opposite of film_in_stock.
inventory_in_stock(inventory_id) returns boolean. 
the function checks whether a single physical copy (inventory_id) is in stock.
get_customer_balance(customer_id, date) returns numeric balance. 
The function calculates the customer’s outstanding balance at a given date. 
inventory_held_by_customer(customer_id) returns a set of inventory items. 
This function lists physical copies currently rented by the customer and not yet returned.
rewards_report (min_monthly_rentals,min_monthly_amount) returns a text list of customers.
last_day(date) returns a date.
The function works by returning the last day of the month for the given period.
2.	rewards_return function returns 0 rows, because the default function uses wrong filtering:
-	it checks rentals for an impossible date range
-	it uses wrong joins
-	incorrectly calculates totals
-	uses dynamic SQL unnecessarily
-	filters out all rows due to incorrect monthly grouping
 */
--corrected version of rewards_report

drop function if exists rewards_report(int,numeric);

create or replace function rewards_report(
    min_monthly_rentals int,
    min_monthly_amount numeric
)
returns text
language plpgsql
as $$
declare
    result text := '';
begin
    select string_agg(
        c.first_name || ' ' || c.last_name,
        ', '
    )
    into result
    from customer c
    join payment p on p.customer_id = c.customer_id
    where date_trunc('month', p.payment_date)
          = date_trunc('month', current_date)
    group by c.customer_id
    having count(*) >= min_monthly_rentals
       and sum(p.amount) >= min_monthly_amount;

    if result is null then
        return 'No rewards this month.';
    end if;

    return result;
end;
$$;
/*
3.	The function that should be removed from dvdrental database is inventory_held_by_customers(). This is due to the fact that this function is redundant, its logic already exists in film_in_stock and rental table queries. It provides no unique functionality.
4.	get_customer_balance function does not fully implement the business rules. Correct implementation must include the following:
unpaid rentals
late fees
payments
return dates rental duration
*/
-- The corrected version of get_customer_balance

create or replace function get_customer_balance(
    p_customer_id int,
    p_date timestamp
)
returns numeric
language plpgsql
as $$
declare
    rentals numeric;
    payments numeric;
begin
    -- total rental charges up to a given date
    select coalesce(sum(f.rental_rate), 0)
    into rentals
    from rental r
    join inventory i on r.inventory_id = i.inventory_id
    join film f on i.film_id = f.film_id
    where r.customer_id = p_customer_id
      and r.rental_date <= p_date;

    -- total payments made by the customer up to that date
    select coalesce(sum(amount), 0)
    into payments
    from payment
    where customer_id = p_customer_id
      and payment_date <= p_date;

    return rentals - payments;
end;
$$;

/*
5.	group_cancat() 
This function combines multiple row values into one comma-seperated string
_group_concat()
A low level helper function used internally by group_concat().
these functions are referenced during the database restore script because PostgreSQL does not natively support group_concat (only string_agg).
They are not used in normal dvdrental logic - only during data import. 
6.	last_updated() function returns the timestamp of the last update of a row. It is used in film, inventory or customer tables. Moreover, it is used in triggers such as:
SQL  
before update on film
for each row 
execute function last_update();
This ensures that a modification timestamp is always correct.
7.	tmpSQL  is a string holding dynamically built SQL
Example:
Plpgsql
tmpSQL := ‘select…where…’;
execute tmpSQL;
It can be rewritten without dynamic SQL , because dynamic SQL is used in the original function for no reason. The entire query can be expressed in a static Select block -
there is no need to dynamically build column or table names.
*/





