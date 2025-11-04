/*Part 1.
 Task 1:The marketing team needs a list of animation movies between 2017 and 2019 to promote family-friendly content
 in an upcoming season in stores. Show all animation movies released during this period with rate more than 1, 
 sorted alphabetically */

select distinct 
f.film_id,f.title, f.release_year,f.rental_rate
from film f 
join film_category fc on fc.film_id=f.film_id
join category c on c.category_id=fc.category_id
where c.name='Animation'
and f.release_year between 2017 and 2019
and f.rental_rate>1
order by f.title asc;

/* The advantages of this solution are: 1. Readable and idiomatic: 1. Straight joins,clear filter, order by functions make this query easy for others to maimntain.
  2. Sargable predicion: c.name = 'Animation' and release_year. 3. Distinct clause - prevents duplicate movie records. 4. Readeable order by clause.
  The disasvanatges of this query are: 1. Limited scalability because multiple joins and sorting can degrade performance as data grows. 2. Sorting on title increase resource usage.
  No pagination or limit means returning full results, which may be excessive for real-world records. 3. Performance reliance on indexes - without proper indexing on film_id, category_id and release_year,
  teh query may trigger costly full table scans and sorting overhead.*/

/* Task2: Revenue by each store since April 2017 (after March 2017)
Output: address+address2 as one column, revenue */

select 
s.store_id, (a.address|| coalesce (' ' || a.address2, '')) as address,
round (sum (p.amount) ::numeric,2) as revenue
from public.payment p
join public.staff st on p.staff_id=st.staff_id
join public.store s on st.store_id=s.store_id
join public.address a on a.address_id=s.address_id
where p.payment_date>=date '2017-04-01'
group by s.store_id, a.address, a.address2
order by s.store_id;

/* The benefits of the provided solution for the second task: 1. The correct aggregation path. 2. Readebly structure. 3. Deterministic rounding gives stable currency_style output.
   The drawbacks of the solution: 1. Open-ended time window - no upper bounds; results change as new paymnets arrive. 2. Potential over-aggregation - if payment.amount includes non-sales transactions for staff,
   they will be included unless filtered. 3. Resource usage is moderate - hash aggregate needs memory proportinal to number of groups.*/

/*Task3:Top-5 actors by number of movies released after 2015
Output columns: first_name, last_name, number_of_movies */

select a.first_name, a.last_name, 
count (*) as number_of_movies
from public.actor a 
join public.film_actor fa on fa.actor_id=a.actor_id
join public.film f on f.film_id=fa.film_id 
where f.release_year>=2015
group by a.actor_id, a.first_name, a.last_name 
order by number_of_movies desc, a.last_name, a.first_name 
limit 5;

/* The advantages of the solution for the task 3: 1. Readable - standart joinss, clear grouping, intuitive order by. 2. Logical naming - meaningful aliases (a,fa,f) make code compact but still understandable.
   3. Limit 5 improves peroformance - restricts output early, minimizing returnes rows.
   The disadvantages of the solution: 1. Static year filter (2015) reduces reusability; needs manual edits for future reporting periods. 2. Ignores role weighting - counts all film appearences equally; lead vs cameo not distinguished.
   3. Actors with equal counts beyond rank 5 are ommitted.*/

-- Task4: Track number of Drama, Travel, and Documentary films per release year
select f.release_year, count(*) filter (where c.name ='Drama') as number_of_drama_movies,
count (*) filter (where c.name='Travel') as number_of_travel_movies,
count (*) filter (where c.name='Documentary') as number_of_documnetary_movies
from public.film f
left join public.film_category fc on f.film_id=fc.film_id 
left join public.category c on fc.category_id=c.category_id 
group by f.release_year 
order by f.release_year desc;

/* Part 2.
   Task1: The HR department aims to reward top-performing employees in 2017 with bonuses to 
   recognize their contribution to stores revenue. Show which three employees generated the most revenue in 2017? */


select 
st.staff_id, st. first_name ||''||st.last_name as employee,
s.store_id,
round(sum(p.amount)::numeric, 2) as revenue
from payment p 
join staff st on st.staff_id=p.staff_id 
join store s on s.store_id=st.store_id 
where p.payment_date>=date '2017-01-01'
and p.payment_date<date '2018-01-01'
group by st.staff_id, st.first_name, st.last_name, s.store_id 
order by revenue desc
limit 3;


/* The benefits of the provided solution for task1: 1. Straight joins, clear date filter, tidy group by.
  2. Correct dimensional model -  fact - first (payment) then dimensions. Filters early on largest table. 3.Only two small dimension joins; nu unnecessary tables.
  The drawbacks: 1. Grouping by s.store_id assumes the staff row reflects the final store. 2. The DB must aggregate all staff/store rows for 2017 before sorting/limiting. On huge datasets, this can be memory heavy (hash aggregate+sort)*/ 

/*Task2:The management team wants to identify the most popular movies and their target audience age groups to optimize marketing efforts. 
 Show which 5 movies were rented more than others (number of rentals), and what's the expected age of the audience for these movies? 
 To determine expected age please use 'Motion Picture Association film rating system'*/

with rating_age as (
select 'G' :: mpaa_rating as rating, 'All ages (~=0+)' as expected_age
union select 'PG' :: mpaa_rating, 'Parental guidance (~=10+)'
union select 'PG-13':: mpaa_rating, '(Teens (~=13+)'
union select 'R' :: mpaa_rating, 'Adults (~=17+)'
union select 'NC-17' :: mpaa_rating, 'Mature adults (~=18+)'
)
select f.title, f.rating, ra.expected_age,
count (r.rental_id) as rental_count
from rental r
join inventory i on r.inventory_id=i.inventory_id 
join film f on i.film_id=f.film_id 
left join rating_age ra on f.rating=ra.rating 
group by f.title, f.rating, ra.expected_age 
order by rental_count desc 
limit 5;

/* The disadvantages of the the solution given above: 1. Readible structure - the CTE defining rating-age mapping is explicit and easy to understand. 2. Proper joins - joins across rental, inventory, film, 
   and rating tables are clean and logically consistent. 3. Scalable result filtering - LIMIT 5 makes output targeted and suitable for reporting dashboards.
   The Disadvantages: 1. Limited time filtering - query counts rental for all time; no date range may lead to results skewed by older data. 2. Rating system assumption - dependent on MPAA ratings; may not generalize to other
   markets. 3. Duplicate group risk - grouping by both title and rating can produce multiple rows per film if data is inconsistent.*/ 
  

/* Part 3.
 Which actors/actresses didn't act for a longer period of time than the others? 
The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career 
breaks for targeted promotional campaigns, highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
V1: gap between the latest release_year and current year per each actor;
V2: gaps between sequential films per each actor.*/

--V1:
select a.actor_id, a.first_name ||''|| a.last_name as actor,
max(f.release_year) as last_release_year,
extract (year from current_date) :: int - max (f.release_year) as inactive_years
from actor a
join film_actor fa on fa.actor_id=a.actor_id
join film f on f.film_id=fa.film_id 
group by a.actor_id, a.first_name, a.last_name 
order by inactive_years desc, actor;

/* The advantages of V1 solution: 1. Simple and readible - one pass, clear (max) aggregation, easy to maintain. 2. Efficient - only one group-by over actors; no window functions needed.
  3. Stable orderng - breaks ties by actor name after sorting by gap.
  The disadvantages: 1. Excludes actors with zero films - uses inner joins; actors who have never acted are not reported. 2. Assumes each film - actor link is unique; duplicate links could inflate work.
  3. Non- deterministic over time - depends on current-date, results change daily, hurting report reproducibility.*/

--V2:
with actor_years as (
select distinct a.actor_id, a.first_name, a.last_name, f.release_year 
from actor a 
join film_actor fa on fa.actor_id=a.actor_id 
join film f on f.film_id=fa.film_id 
where f.release_year is not null
),
prev_year as (
select ay.actor_id, ay.first_name, ay.last_name, 
ay.release_year as year2,
(
select max (ay2.release_year)
from actor_years ay2
where ay2.actor_id=ay.actor_id
and ay2.release_year<ay.release_year
) as year1
from actor_years ay
),
gaps as (
select actor_id,first_name,last_name, (year2-year1) as gap_years
from prev_year 
where year1 is not null
)
select actor_id, first_name ||''|| last_name as actor, max(gap_years) as max_gap_years
from gaps
group by actor_id, first_name, last_name 
order by max_gap_years desc, actor;

/* The advantages of the solution: 1. Window free - uses correlated subquery(select max(...) where release_year <current) instead of lag(..). 2. Readable staging - CTEs make the logic easy to follow. 
  3. Deduped years - select distinct ...release_year avoids double counting.
  The drawbacks: 1. Excludes actors with zero films. 2. Correlated subquery cost. 3. Duplicates across titles in same year - if an actor has multiple films in one year, the gap for that year is 0; acceptable but woth noting.
  Inner join is used between actor and film_actor, between film_actor and film (retrieves release_year for each linked film)
 */




