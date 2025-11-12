
--Choose your real top-3 favorite movies and add them to the 'film' table

insert into film (title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, special_features
)
values ('Avatar', 
'A paraplegic MArine is sent to the alien world of Pandora, where he becomes part of the native Na''vi culture and must choose between protecting their home and fulfilling his military mission.', 
2009,
1,
1,
7,
4.99,
162,
19.99,
'PG-13',
'{"Trailers","Deleted Scenes","Behind the Scenes"}'
);

insert into film (title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, special_features
)
values ('TITANIC', 'A romance unfolds abroad the ill-fated RMS Titanic.', 1997,1,1,7,9.99,195, 19.99,'PG-13','{Trailers}'),
       ('THE GREAT GATSBY', 'A mysterious millionaire throws lavish parties hoping to reunite with his lost  love', 2013,1,1,7,19.99,143, 20.99,'PG-13','{Trailers}'); 


update film  --Update function was used, because firstly the wrong values were inserted into the column rental_duration for all three new  films
set rental_duration=1
where title='Avatar';

update film
set rental_duration=2
where title='TITANIC'; 

update film
set rental_duration=3
where title='THE GREAT GATSBY';

--Add new actors (if not already in the table)
insert into actor (first_name,last_name, last_update)
select first_name,last_name, current_date
from (
values
('SAM', 'WORTHINGTON'),
('ZOE', 'SALDANA'),
('LEONARDO','DICAPRIO'),
('KATE', 'WINSLET'),
('CAREY','MULLIGAN'),
('GIOVANNI','RIBISI')
) as new_actors (first_name,last_name)
where not exists (
select 1 from actor a 
where a.first_name=new_actors.first_name
and a.last_name=new_actors.last_name
)
returning actor_id,first_name,last_name;


select max(actor_id) from actor; --there were some errors in the sequence of actor_id, which were fixed using update function

alter sequence actor_actor_id_seq restart with 201;

update film set film_id=1002 where title='TITANIC';
update film set film_id=1003 where title='THE GREAT GATSBY';

--Add the real actors who play leading roles in your favorite movies to the 'film_actor' tables (6 or more actors in total).
insert into film_actor (actor_id,film_id,last_update)
select a.actor_id, f.film_id, current_date
from actor a
join film f on f.title in ('Avatar', 'TITANIC', 'THE GREAT GATSBY')
where(a.first_name, a.last_name, f.title) in (
('SAM', 'WORTHINGTON', 'Avatar'),
('ZOE', 'SALDANA','Avatar'),
('LEONARDO','DICAPRIO','TITANIC'),
('KATE', 'WINSLET', 'TITANIC'),
('CAREY','MULLIGAN','THE GREAT GATSBY'),
('GIOVANNI','RIBISI', 'Avatar') 
)
and not exists (
select 1 from film_actor fa 
where fa.actor_id=a.actor_id and fa.film_id=f.film_id 
)
returning actor_id,film_id,last_update;

--Add your favorite movies to any store's inventory.
insert into inventory (film_id, store_id, last_update)
select f.film_id,1,current_date 
from film f
where f.title in ('Avatar','TITANIC', 'THE GREAT GATSBY')
and not exists (
select 1
from inventory i 
where i.film_id=f.film_id 
and i.store_id=1
)
returning inventory_id, film_id, store_id; 

--Alter any existing customer in the database with at least 43 rental and 43 payment records
update customer 
set first_name = 'Oydin',
last_name='Fayzullaeva',
email='oydinaa1818@gmail.com',
last_update = current_date  
where customer_id =(
select c.customer_id
from customer c
join rental r on c.customer_id=r.customer_id 
join payment p on c.customer_id=p.customer_id 
group by c.customer_id 
having count (distinct r.rental_id)>=43
and count(distinct p.payment_id)>=43 
limit 1)
returning customer_id, first_name,last_name, email;

--Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory'
begin;
--1) Identifying "my_info" (the  customer that was updated earlier).
with my_info as (
select customer_id
from customer 
where email='oydinaa1818@gmail.com'
and first_name='Oydin' 
and last_name='Fayzullaeva'
limit 1 
)
--2)Delete payments made by my_info(return what was moved for proof)
,del_pay as (
delete from payment p 
using my_info 
where p.customer_id=my_info.customer_id
returning p.payment_id, p.rental_id,p.amount, p.payment_date
)
--Delete my rentals (return what was removed for proof)
delete from rental r
using my_info
where r.customer_id=my_info.customer_id
returning r.rental_id, r.inventory_id, r.rental_date,r.return_date;


--Rent you favorite movies from the store they are in and pay for them (add corresponding records to the database to represent this activity)
BEGIN;

WITH my_info AS (
  SELECT customer_id
  FROM customer
  WHERE lower(email)=lower('oydinaa1818@gmail.com')
  LIMIT 1
),
favs AS (
  SELECT film_id, title, rental_rate
  FROM film
  WHERE title IN ('Avatar','TITANIC','THE GREAT GATSBY')
),
inv AS (  -- one copy per film in store 1
  SELECT DISTINCT ON (i.film_id) i.inventory_id, i.film_id
  FROM inventory i 
  JOIN favs USING (film_id)
  WHERE i.store_id = 1
  ORDER BY i.film_id, i.inventory_id
),
st AS (
  SELECT staff_id FROM staff WHERE store_id = 1 ORDER BY staff_id LIMIT 1
),
rent AS (
  INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
  SELECT
    (DATE '2017-05-15' + (ROW_NUMBER() OVER (ORDER BY inv.film_id)-1) * INTERVAL '1 day')::timestamp,
    inv.inventory_id,
    my_info.customer_id,
    (DATE '2017-05-18' + (ROW_NUMBER() OVER (ORDER BY inv.film_id)-1) * INTERVAL '1 day')::timestamp,
    st.staff_id,
    CURRENT_DATE
  FROM inv
  CROSS JOIN my_info
  CROSS JOIN st
  WHERE NOT EXISTS (
    SELECT 1
    FROM rental r
    WHERE r.inventory_id = inv.inventory_id
      AND r.customer_id  = my_info.customer_id
      AND r.rental_date::date BETWEEN DATE '2017-05-15' AND DATE '2017-05-20'
  )
  RETURNING rental_id, inventory_id, customer_id, staff_id, rental_date
),
pay AS (
  INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
  SELECT
    r.customer_id,
    r.staff_id,
    r.rental_id,
    f.rental_rate::numeric(5,2),             -- fixed cast
    (r.rental_date + INTERVAL '1 day')::timestamp
  FROM rent r
  JOIN inv  i ON i.inventory_id = r.inventory_id  -- use CTE inv
  JOIN film f ON f.film_id      = i.film_id
  WHERE NOT EXISTS (SELECT 1 FROM payment p WHERE p.rental_id = r.rental_id)
  RETURNING payment_id, rental_id, amount, payment_date
)
SELECT f.title, r.rental_id, p.payment_id, p.amount, p.payment_date
FROM rent r
JOIN inv  i ON i.inventory_id = r.inventory_id      -- use CTE inv
JOIN film f ON f.film_id      = i.film_id
LEFT JOIN pay p ON p.rental_id = r.rental_id
ORDER BY f.title;




