For the small neighborhood we have the data model,
neighborhood: [street name, home number, apartment_number, first_name, second_name]
Please write a query to get the most populated street name.
And provide person’s info - first_name, second_name who lives on that street.
 

select street_name,first_name,second_name 
from neighborhood 
where street_name=( 
select street_name
from neighborhood
group by street_name 
order by count(*) desc
limit 1 
);