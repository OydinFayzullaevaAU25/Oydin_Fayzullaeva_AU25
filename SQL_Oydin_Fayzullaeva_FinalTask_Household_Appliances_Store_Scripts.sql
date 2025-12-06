--Creating a physical database
--0. Create schema for this domain
create schema if not exists household_store;
set search_path to household_store;
--1. Parent tables (no foreign keys to other tables)
--category 
create table category (
category_id integer generated always as identity,
category_name varchar (100) not null,
constraint pk_category_category_id primary key (category_id),
constraint uq_category_category_name unique (category_name)
);
--customer
create table customer (
customer_id integer generated always as identity,
full_name varchar(150) not null,
phone varchar(20) not null,
email  varchar(150),
constraint pk_customer_customer_id primary key (customer_id),
constraint uq_customer_email unique (email)
);
--employee 
create table employee (
employee_id integer generated always as identity,
full_name varchar(150) not null,
position varchar(100) not null, 
constraint pk_employee_employee_id primary key (employee_id) 
);

--supplier
create table supplier (
supplier_id integer generated always as identity,
supplier_name varchar(150) not null,
contact_phone varchar(20) not null,
contact_email varchar(150),
constraint pk_supplier_supplier_id primary key (supplier_id),
constraint uq_supplier_cantact_email unique (contact_email)
);
--2. Product (FK-category)
create table product (
product_id integer generated always as identity,
product_name varchar(150) not null,
brand varchar(100) not null,
model varchar(100) not null,
price numeric(10,2) not null,
stock_quantity integer not null default 0,
category_id integer,
constraint pk_product_product_id primary key (product_id),
constraint fk_product_category_id foreign key (category_id) references category (category_id),
constraint chk_product_price_positive check (price>0),
constraint chk_product_stock_non_negative check (stock_quantity>=0)
);

--3. Orders (FK-customer, employee)

create table orders(
order_id integer generated always as identity,
order_date date not null default current_date,
customer_id integer,
employee_id integer,
order_status varchar(20) not null default 'pending',
constraint pk_orders_order_id primary key (order_id),
constraint fk_orders_customer_id foreign key (customer_id) references customer (customer_id),
constraint fk_orders_employee_id foreign key (employee_id) references employee (employee_id),
constraint chk_orders_status_allowed_values check (order_status in ('pending','shipped', 'delivered','canceled')),
constraint chk_orders_date_not_before_2024 check (order_date >= date '2024-01-01')
);

-- 4. Bridge tables (M:N relationships)
--product - supplier

create table product_supplier (
product_id integer not null,
supplier_id integer not null,
procurement_price numeric(10,2) not null,
last_supply_date date,
constraint pk_product_supplier primary key (product_id,supplier_id),
constraint fk_product_supplier_product_id foreign key (product_id) references product (product_id),
constraint fk_product_supplier_supplier_id foreign key (supplier_id) references supplier (supplier_id),
constraint chk_procurement_price_positive check (procurement_price > 0)
);

--5. Bridge table (M:N relationships)
--orders-product
create table order_item (
order_id integer not null,
product_id integer not null,
quantity integer not null,
price_at_sale numeric (10,2) not null,
line_total numeric (12,2) generated always as (quantity * price_at_sale) stored,
constraint pk_order_item primary key (order_id, product_id),
constraint fk_order_item_order_id foreign key (order_id) references orders (order_id),
constraint chk_order_item_quantity_positive check (quantity > 0),
constraint chk_order_item_price_at_sale_positive check (price_at_sale > 0)
);

select *
from orders;

-- Populating tables

insert into category (category_name) values 
('Refrigerators'),
('Washing Machines'),
('Televisions'),
('Kitchen Appliances'),
('Vacuum Cleaners'),
('Air conditioners');

insert into customer (full_name, phone, email) values
('Emily Johnson', '+998901111111', 'emily.johnson@gmail.com'),
('Michael Smith', '+998902222222', 'michael.smith@gmail.com'),
('Daniel Brown',  '+998903333333', 'daniel.brown@gmail.com'),
('Laura Davis',   '+998904444444', 'laura.davis@example.com'),
('Robert Wilson', '+998905555555', 'robert.wilson@example.com'),
('Sophia Miller', '+998906666666', 'sophia.miller@example.com');

insert into employee (full_name, position) values
  ('Alex Brian',    'Sales Consultant'),
  ('James Blur',    'Sales Consultant'),
  ('Cathy Simons',      'Cashier'),
  ('David Brown',    'Store Manager'),
  ('Mary Simpsons',     'Warehouse Manager'),
  ('Claire Hayes',  'Online Sales Specialist');

select *
from product;

insert into supplier (supplier_name, contact_phone, contact_email) values
  ('UzFridge LLC',        '+998711111111', 'info@uzfridge.uz'),
  ('TashTech Import',     '+998712222222', 'sales@tashtech.uz'),
  ('AsiaElectro Trade',   '+998713333333', 'contact@asiaelectro.uz'),
  ('Premium Appliances',  '+998714444444', 'office@premium-app.uz'),
  ('Global TV Supply',    '+998715555555', 'support@globaltv.uz'),
  ('Comfort Climate',     '+998716666666', 'info@comfortclimate.uz');
-- (we are assuming that category_id 1..6 from inserts above)

insert into product
  (product_name, brand, model, price, stock_quantity, category_id)
values
  ('NoFrost 320L Fridge',         'Artel',   'NF-320',   4500000.00, 15, 1),
  ('Inverter Washing Machine',    'Samsung', 'WW80T',    5200000.00, 10, 2),
  ('4K Smart TV 55"',             'LG',      '55UQ800',  6800000.00,  8, 3),
  ('Microwave Oven 25L',          'Panasonic','NN-S25', 1800000.00, 20, 4),
  ('Bagless Vacuum Cleaner',      'Bosch',   'BCS-21',   2300000.00, 12, 5),
  ('Split AC 12k BTU',            'Midea',   'MS12HR',   5400000.00,  7, 6),
  ('Top Freezer 260L Fridge',     'Artel',   'TF-260',   3800000.00, 18, 1),
  ('Front Load Washing Machine',  'LG',      'F4J6',     5600000.00,  9, 2);

insert into orders (order_date, customer_id, employee_id, order_status) values
  (DATE '2025-09-15', 1, 1, 'delivered'),
  (DATE '2025-09-28', 2, 2, 'delivered'),
  (DATE '2025-10-05', 3, 3, 'shipped'),
  (DATE '2025-10-19', 4, 4, 'pending'),
  (DATE '2025-11-02', 5, 2, 'delivered'),
  (DATE '2025-11-18', 6, 1, 'canceled'),
  (DATE '2025-11-25', 1, 5, 'shipped'),
  (DATE '2025-12-01', 3, 6, 'pending');

insert into product_supplier
  (product_id, supplier_id, procurement_price, last_supply_date)
values
  (1, 1, 3700000.00, DATE '2025-09-01'),
  (7, 1, 3100000.00, DATE '2025-10-10'),
  (2, 2, 4300000.00, DATE '2025-09-12'),
  (8, 2, 4700000.00, DATE '2025-10-22'),
  (3, 5, 5600000.00, DATE '2025-09-18'),
  (4, 3, 1400000.00, DATE '2025-11-03'),
  (5, 3, 1800000.00, DATE '2025-10-14'),
  (6, 6, 4500000.00, DATE '2025-11-20'),
  (3, 4, 5900000.00, DATE '2025-11-28'),
  (5, 2, 1900000.00, DATE '2025-09-25');

insert into order_item 
(order_id, product_id, quantity, price_at_sale)
values
  (17, 1, 1, 4500000.00),
  (18, 4, 1, 1800000.00),
  (19, 2, 1, 5200000.00),
  (20, 5, 1, 2300000.00),
  (21, 3, 1, 6800000.00),
  (22, 4, 2, 1750000.00);

--5. Functions
--5.1. Creating functions that updates data.
SET search_path TO household_store;

create or replace function update_order_column(
    p_order_id     integer,   -- PK value of orders.order_id
    p_column_name  text,      -- name of the column to update
    p_new_value    text       -- new value as text (will be cast)
)
returns void
language plpgsql
as $$
declare 
    v_sql text;
begin
    -- Build UPDATE statement with dynamic column name.
    -- %I safely quotes the identifier (column name).
    v_sql := format(
        'UPDATE household_store.orders
         SET %I = $1
         WHERE order_id = $2',
        p_column_name
    );

    -- Execute dynamic SQL, passing the new value and PK as parameters.
    execute v_sql using p_new_value, p_order_id;

    -- Give feedback whether a row was updated
    if not found then  
        raise notice 'No order found with order_id = %', p_order_id;
    else 
        raise notice 'Order % updated: column % set to %',
                     p_order_id, p_column_name, p_new_value;
    end if ;
end ;
$$;

--5.2 Adding a new transaction
set search_path to household_store;

create or replace function add_order_transaction(
    p_order_date date,
    p_customer_name text,
    p_employee_name text,
    p_product_name text,
    p_quantity integer,
    p_price_at_sale numeric(10,2),
    p_order_status text default 'pending'
)
returns void
language plpgsql
as $$
declare
    v_customer_id integer;
    v_employee_id integer;
    v_product_id integer;
    v_order_id integer;
begin
    -- find customer by natural key
    select customer_id
    into v_customer_id
    from customer
    where full_name = p_customer_name;

    if v_customer_id is null then
        raise exception 'customer "%" not found', p_customer_name;
    end if;

    -- find employee by natural key
    select employee_id
    into v_employee_id
    from employee
    where full_name = p_employee_name;

    if v_employee_id is null then
        raise exception 'employee "%" not found', p_employee_name;
    end if;

    -- find product by natural key
    select product_id
    into v_product_id
    from product
    where product_name = p_product_name;

    if v_product_id is null then
        raise exception 'product "%" not found', p_product_name;
    end if;

    -- insert into orders and return generated order id
    insert into orders (order_date, customer_id, employee_id, order_status)
    values (p_order_date, v_customer_id, v_employee_id, p_order_status)
    returning order_id into v_order_id;

    -- insert into order_item
    insert into order_item (order_id, product_id, quantity, price_at_sale)
    values (v_order_id, v_product_id, p_quantity, p_price_at_sale);

    -- confirmation message
    raise notice 'new transaction created: order_id=%, customer="%", product="%", quantity=%',
        v_order_id, p_customer_name, p_product_name, p_quantity;
end;
$$;

--6.Creating a view
set search_path to household_store;

create or replace view v_sales_analytics_latest_quarter as
with latest_quarter as (
    select date_trunc('quarter', max(order_date))::date as q_start
    from household_store.orders
),
quarter_orders as (
    select o.order_id, o.order_date
    from household_store.orders o
    join latest_quarter lq
      on o.order_date >= lq.q_start
     and o.order_date < (lq.q_start + interval '3 months')
)
select
    to_char(lq.q_start, 'yyyy-"q"q') as quarter_label,
    c.category_name,
    p.product_name,
    sum(oi.quantity) as total_quantity,
    sum(oi.quantity * oi.price_at_sale) as total_revenue
from quarter_orders qo
join household_store.order_item oi
  on oi.order_id = qo.order_id
join household_store.product p
  on p.product_id = oi.product_id
join household_store.category c
  on c.category_id = p.category_id
join latest_quarter lq on true
group by
    quarter_label,
    c.category_name,
    p.product_name;
-- in order to test view, the following query was used
select *
from v_sales_analytics_latest_quarter
order by total_revenue desc;

--7.
--create the role
--Role should not have superuser or write permissions.
create role manager_readonly login password 'manager123';
--revoke all default public privileges
--to ensure minimal privilege principle:
revoke all on schema public from public;
revoke all on all tables in schema public from public;
revoke all privileges on database postgres from manager_readonly;
--grant read-only access only to the correct schema objects
--the manager should see analytics but not modify data.
grant usage on schema household_store to manager_readonly;
--this includes tables + views because PostgreSQL treats views as tables for SELECT rights
grant select on all tables in schema household_store to manager_readonly;

