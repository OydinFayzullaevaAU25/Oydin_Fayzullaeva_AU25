
--Task 1
SELECT 
    rolname,
    rolsuper::text,
    rolinherit::text,
    rolcreaterole::text,
    rolcreatedb::text,
    rolreplication::text,
rolcanlogin::text
FROM pg_roles;

SELECT table_schema, table_name, privilege_type, grantee
FROM information_schema.table_privileges
ORDER BY table_schema, table_name;

SELECT *
FROM pg_policies;

SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE rowsecurity = true;

SELECT datname, datconnlimit
FROM pg_database;

--Task 2
--Part 1
create role rentaluser login password 'rentalpassword';
grant connect on database dvdrental to rentaluser;

--Part 2
--the user rentaluser needed select access to the customer table.The following command was executed:
grant select on table customer to rentaluser;

after granting this privilege, a test was performed by connecting as rentaluser and running:

select * from customer;

--the query executed successfully and returned all rows, confirming that the select permission works correctly.
--attempts to select from other tables (such as rental) still produced permission errors, which verifies that only the required privilege was granted.

--Part 3
--To implement role-based security, a group role named rental was created using:
create role rental;

--since this role does not have login capability, it serves as a user group. the login role rentaluser was then added to this group:
grant rental to rentaluser;

--this setup allows rentaluser to inherit any permissions that will be granted to the rental group in the following steps.

--Part 4
--to allow data modifications for rentals, insert and update privileges were granted to the rental group on the rental table:
grant insert, update on table rental to rental;

--since rentaluser is a member of this group, the user inherits these permissions. after connecting to the dvdrental database as rentaluser, a new row was inserted into the rental table using valid foreign key values:
insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id)
values ('2025-11-27 10:00:00', 1, 1, null, 1);

the insert executed successfully. next, an existing rental record was updated:

update rental
set return_date = current_timestamp
where rental_id = 1;
--this update also completed without error, confirming that the rental group has working insert and update permissions on the rental table and that rentaluser correctly inherits these privileges via group membership.
--Part 5
select rolname,rolcanlogin from pg_roles;
alter role rentaluser with login password 'rentalpassword';
grant connect on database dvdrental to rentaluser;
grant usage on schema public to rentaluser;

--to restrict data modification rights, the insert privilege was revoked from the rental group:
revoke insert on table rental from rental;
--after that, a new session was opened using the rentaluser account (member of the rental group). when trying to insert a new row into the rental table:

insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id)
values ('2025-11-27 12:00:00', 1, 1, null, 1);

--the database returned an error “permission denied for table rental”. this confirms that the insert privilege was successfully revoked from the group and that rentaluser no longer has the ability to insert rows into the rental table, while the previously granted update privilege is still in effect.
--but you can see it in the next sql script which was created for this task only and is connected to dvdrental, rentaluser, current SQL script is connected to postgres
--Part 6
--to implement personalized access, a dedicated role was created for an existing customer whose rental and payment history is not empty. first, such a customer was identified:

select distinct c.customer_id, c.first_name, c.last_name
from customer c
join rental  r on r.customer_id = c.customer_id
join payment p on p.customer_id = c.customer_id
order by c.customer_id
limit 1;

--in my case, the selected customer was mary smith. according to the task, a new login role named client_mary_smith was created:

create role client_mary_smith
    login
    password 'clientpassword';
--the role was then granted the ability to connect to the dvdrental database and basic read access to the relevant tables:

grant connect on database dvdrental to client_mary_smith;
grant usage on schema public to client_mary_smith;
grant select on customer, rental, payment to client_mary_smith;

--querying pg_roles confirmed that the role exists and has the login flag set, which means it can be used as a personalized account representing this particular customer.
