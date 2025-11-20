--Creating database
  create database subway_db;
--Creating scheme
create schema subway;
set search_path to subway; --we need this command to avoid writing the name of the scheme every time

--MASTER TABLES (PARENTS)
create table if not exists maintenance_type (
maintenance_type_id integer generated always as identity,
maintenanc_type varchar(100) not null,
maintenance_description varchar(255) not null,
constraint pk_maintenance_type_maintenance_type_id primary key (maintenance_type_id)
);


create table if not exists line( 
line_id bigint generated always as identity,
line_name varchar(50) not null,
required_trains integer not null,
required_employess integer not null,
constaint pk_line_line_id primary key (line_id)
);

create table if not exists train ( 
train_id integer generated always as identity,
headcode varchar(20),
model varchar(50) not null,
manufacturer varchar(50),
status varchar(20) check(status in ('Active','Maintenance', 'Retired')),
constraint pk_train_train_id primary key (train_id)
);


create table if not exists station (
station_id integer generated always as identity,
station_name varchar(50),
station_latitude decimal (9,6),
station_longitude decimal(9,6),
capacity integer not null,
constraint pk_station_station_id primary key (station_id)
);


--DEPENDENT TABLES (CHILDREN) 

create table if not exists tunnel ( 
tunnel_id integer generated always as identity,
start_station_id integer not null,
end_station_id integer not null, 
constraint pk_tunnel_tunnel_id primary key (tunnel_id),
constraint fk_tunnel_start_station_id foreign key (start_station_id) references station (station_id),
constraint fK_tunnel_end_station_id foreign key (end_station_id) references station (station_id)
);


create table if not exists track(
track_id integer generated always as identity,
start_station_id integer,
end_station_id integer ,
direction varchar (20) check (direction in ('north', 'south', 'east','west')),
constraint pk_rrack_track_id primary key (track_id),
constraint fk_track_start_station_id foreign key (start_station_id) references station (station_id),
constraint fK_track_end_station_id foreign key (end_station_id) references station (station_id)
);


create table if not exists object_maintenance( 
maintenance_type_id integer generated always as identity,
train_id integer,
tunnel_id integer,
track_id integer,
station_id integer,
start_date date not null check(start_date>'2000-01-01'), 
end_date date check(end_date is null or end_date>'2000-01-01'),
cost decimal (9,6),
description varchar(200),
constraint fk_object_maintenance_maintenance_type_id  foreign key (maintenance_type_id) references maintenance_type (maintenance_type_id),
constraint fk_object_maintenance_train_id foreign key (train_id) references train (train_id),
constraint fk_object_maintenance_track_id foreign key (track_id) references track (track_id),
constraint fk_object_maintenance_station_id foreign key (station_id) references station (station_id),
constraint fk_object_maintenance_tunnel_id foreign key (tunnel_id) references tunnel (tunnel_id)
);


create table if not exists line_station (
line_station_id integer generated always as identity,
line_id integer,
station_id integer,
sequence_number integer not null check (sequence_number>0),
constraint pk_line_station_line_station_id primary key (line_station_id),
constraint fk_line_station_line_id foreign key (line_id) references line (line_id),
constraint fk_line_station_station_id foreign key (station_id) references station (station_id)
);

create table if not exists train_line_assignment( 
train_id integer not null,
line_id bigint not null,
start_date date not null check(start_date>'2000-01-01'),
end_date date check(end_date is null or end_date>=start_date),
constraint fk_train_line_assignment_train_id foreign key (train_id) references train (train_id),
constraint fk_train_line_assignment_line_id foreign key (line_id) references line (line_id)
);


create table if not exists train_schedule(
train_id integer not null,
station_id integer not null,
line_station_id integer not null,
arrival_datetime timestamp not null check (arrival_datetime>'2000-01-01 00:00:00'),
departure_datetime timestamp not null check (departure_datetime>arrival_datetime),
constraint fk_train_schedule_train_id foreign key (train_id) references train (train_id),
constraint fk_train_schedule_station_id foreign key (station_id) references station (station_id),
constraint fk_train_schedule_line_station_id foreign key (line_station_id) references line_station (line_station_id)
);

create table if not exists ticket( 
ticket_id integer generated always as identity,
ticket_type varchar(50) not null,
price decimal (8,2) check (price>=0),
constraint pk_ticket_ticket_id primary key (ticket_id)
);

create table if not exists promotion ( 
promotion_id integer generated always as identity,
promotion_name varchar(100) not null,
start_date date not null check (start_date>'2000-01-01'),
end_date date not null check (end_date>start_date),
discount_amount decimal (6,2) check (discount_amount>=0),
constraint pk_promotion_promotion_id primary key (promotion_id)
);

create table if not exists transaction_table ( 
ticket_id integer not null,
promotion_id integer not null,
station_id integer not null, 
quantity integer check (quantity>=0),
purchase_datetime timestamp not null check (purchase_datetime>'2000-01-01 00:00:00'),
constraint fk_transaction_table_ticket_id foreign key (ticket_id) references ticket (ticket_id),
constraint fk_transaction_table_station_id foreign key (station_id) references station (station_id),
constraint fk_transaction_table_promotion_id foreign key (promotion_id) references promotion (promotion_id)
);

-- Populating the tables with sample data

insert into line (line_name,required_trains,required_employees)
values ('Green Line',20,160),
       ('Red Line', 24,190);

alter table maintenance_type rename column maintenanc_type to maintenance_type;--here I noticed some spelling errors with the name of the column, so alter table command was used

insert into maintenance_type (maintenance_type, maintenance_description)
values ('Brake Inspection','Routine brake check and pad replacement'),
       ('Rail Grinding','Smooth rail surface to reduce noise');


insert into train (headcode, model, manufacturer,status)
values ('G-220','CityRunner','Siemens', 'Active'),
	   ('R-300', 'MetroFlex','Alstom','Active');

insert into station (station_name,station_latitude, station_longitude,capacity)
values ('Central Square', 41.4036, 2.1740,6000),
       ('Park Street', 42.4050,2.1800,4500);

insert into tunnel (start_station_id,end_station_id)
values (1,2),
	   (1,2);

insert into track (start_station_id,end_station_id,direction)
values (1,2,'north'),
	   (1,2,'south');


insert into object_maintenance (Train_ID,Tunnel_ID,Track_ID,Station_ID,start_date,end_date,cost,description)
values (1,2,2,1,'2000-01-15','2000-01-21',350.00,'Brake pads replaced'),
       (1,1,2,2,'2000-02-10','2000-01-19',510.00,'Rail grinding')
on conflict do nothing;


insert into line_station (line_id,station_id,sequence_number)
values (2,1,2),
	   (1,2,1) 
on conflict do nothing;	


insert into train_line_assignment (train_id,line_id, start_date,end_date)
values (2,2,'2000-01-20','2000-02-01'),
       (1,2,'2000-02-08','2000-02-19')
       on conflict do nothing;

insert into train_schedule(train_id,station_id, line_station_id,arrival_datetime,departure_datetime)
values (1,2,2,'2000-01-10 05:00:00','2000-01-20 06:00:00.000'), 
       (2,2,1,'2000-02-02 10:00:00','2000-02-10 11:00:00.000')
       on conflict do nothing;


insert into ticket(ticket_type,price)
values ('single',10.00),
       ('day pass',17.00)
       on conflict do nothing;

insert into promotion (promotion_name,start_date,end_date,discount_amount)
values ('Spring sale','2000-01-05','2000-01-15',0.50),
       ('Weeekend deal','2000-02-05','2000-02-15', 1.00)
       on conflict do nothing;

insert into transaction_table (ticket_id,promotion_id,station_id,quantity,purchase_datetime)
values(1,2,1,4,'2000-01-10 08:00:00.000'),
      (2,2,1,6,'2000-01-11 09:00:00.000')
      on conflict do nothing;

--Adding a new field
alter table maintenance_type add column if not exists record_ts timestamp default current_timestamp;
alter table line add column if not exists record_ts timestamp default current_timestamp;
alter table train add column if not exists record_ts timestamp default current_timestamp;
alter table station add column if not exists record_ts timestamp default current_timestamp;
alter table tunnel add column if not exists record_ts timestamp default current_timestamp;
alter table track add column if not exists record_ts timestamp default current_timestamp;
alter table object_maintenance add column if not exists record_ts timestamp default current_timestamp;
alter table line_station add column if not exists record_ts timestamp default current_timestamp;
alter table train_line_assignment add column if not exists record_ts timestamp default current_timestamp;
alter table train_schedule add column if not exists record_ts timestamp default current_timestamp;
alter table ticket add column if not exists record_ts timestamp default current_timestamp;
alter table promotion add column if not exists record_ts timestamp default current_timestamp;
alter table transaction_table add column if not exists record_ts timestamp default current_timestamp;



