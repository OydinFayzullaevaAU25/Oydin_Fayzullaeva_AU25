--Creating database
create database subway_db;
--Creating scheme
create schema subway;
set search_path to subway; --we need this command to avoid writing the name of the scheme every time

--MASTER TABLES (PARENTS)
create table if not exists maintenance_type (
PK_Maintenance_Type_Maintenance_Type_ID integer primary key,
Maintenanc_Type varchar(100) not null,
Maintenance_Description varchar(255) not null);

create table if not exists Line( 
PK_Line_Line_ID bigint primary key,
Line_Line_Name varchar(50) not null,
Line_Required_Trains integer not null,
Line_Required_employess integer not null);

create table if not exists train ( 
PK_Train_Train_ID integer primary key,
headcode varchar(20),
model varchar(50) not null,
manufacturer varchar(50),
status varchar(20) check(status in ('Active','Maintenance', 'Retired'))
);

create table if not exists station (
PK_Station_Station_ID integer primary key,
Station_Name varchar(50),
Station_Latitude decimal (9,6),
Station_longitude decimal(9,6),
Capacity integer not null);

--DEPENDENT TABLES (CHILDREN) 

create table if not exists tunnel ( 
PK_Tunnel_Tunnel_ID integer primary key,
FK_Tunnel_Start_Station_ID integer references Station (PK_Station_Station_ID),
FK_Tunnel_End_Station_ID integer references Station (PK_Station_Station_ID)
);

create table if not exists track(
PK_Track_Track_ID integer primary key,
FK_Track_Start_Station_ID integer references Station (PK_Station_Station_ID),
FK_Track_End_Station_ID integer references Station (PK_Station_Station_ID),
Direction varchar (20) check (direction in ('north', 'south', 'east','west'))
);

create table if not exists object_maintenance( 
FK_Object_Maintenance_Maintenance_ID integer references Maintenance_Type (PK_Maintenance_Type_Maintenance_Type_ID),
FK_Object_Maintenance_Train_ID integer references Train(PK_Train_Train_ID),
FK_Object_Maintenance_Track_ID integer references Track(PK_Track_Track_ID),
FK_Object_Maintenance_Station_ID integer references Station(PK_Station_Station_ID),
FK_Object_Maintenance_Tunnel_ID integer references Tunnel (PK_Tunnel_Tunnel_ID),
Start_Date date not null check(start_date>'2000-01-01'), 
End_Date date check(end_date is null or end_date>'2000-01-01'),
cost decimal (9,6),
Description varchar(200)
);

create table if not exists Line_Station (
PK_Line_Station_Line_Station_ID integer primary key,
FK_Line_Station_Line_ID integer references Line(PK_Line_Line_ID),
FK_Line_Station_Station_ID integer references Station (PK_Station_Station_ID),
sequence_number integer not null check (sequence_number>0)
);

create table if not exists Train_Line_Assignment( 
FK_Train_Line_Assignment_Train_ID integer references Train(PK_Train_Train_ID),
FK_Train_Line_Assignment_Line_ID bigint references Line(PK_Line_Line_ID),
Start_Date date not null check(start_date>'2000-01-01'),
End_Date date check(end_date is null or end_date>=start_date)
);

create table if not exists Train_Schedule(
FK_Train_Schedule_Train_ID integer references Train(PK_Train_Train_ID),
FK_Train_Schedule_Station_ID integer references Station (PK_Station_Station_ID),
FK_Train_Schedule_Line_Station_ID integer references Line_Station (PK_Line_Station_Line_Station_ID),
Arrival_Datetime timestamp not null check (Arrival_Datetime>'2000-01-01'),
Departure_Datetime timestamp not null check (Departure_Datetime>Arrival_Datetime)
);

create table if not exists Ticket( 
PK_Ticket_Ticket_ID integer primary key,
Ticket_Type varchar(50) not null,
Price decimal (8,2) check (price>=0)
);

create table if not exists Promotion ( 
PK_Promotion_Promotion_ID integer primary key,
Promotion_Name varchar(100) not null,
Start_Date date not null check (Start_Date>'2000-01-01'),
End_Date date not null check (End_Date>Start_Date),
Discount_Amount decimal (6,2) check (discount_amount>=0)
);

create table if not exists Transaction_Table ( 
FK_Transaction_Table_Ticket_ID integer references Ticket (PK_Ticket_Ticket_ID),
FK_Transaction_Table_Promotion_ID integer references Promotion (PK_Promotion_Promotion_ID),
FK_Transaction_Table_Station_ID integer references Station (PK_Station_Station_ID),
Quantity integer check (quantity>=0),
Purchase_Datetime timestamp not null check (purchase_datetime>'2000-01-01')
);

-- Populating the tables with sample data

insert into line (pk_line_line_id,line_line_name, line_required_trains, line_required_employess)
values (1,'Green Line',20,160),
       (2,'Red Line', 24,190);

alter table maintenance_type rename column maintenanc_type to maintenance_type;--here I noticed some spelling errors with the name of the column, so alter table command was used

insert into maintenance_type (pk_maintenance_type_maintenance_type_id,maintenance_type, maintenance_description)
values (1, 'Brake Inspection','Routine brake check and pad replacement'),
       (2,'Rail Grinding','Smooth rail surface to reduce noise');

insert into train (pk_train_train_id, headcode, model, manufacturer,status)
values (1,'G-220','CityRunner','Siemens', 'Active'),
	   (2,'R-300', 'MetroFlex','Alstom','Active');

insert into station (pk_station_station_id, station_name,station_latitude, station_longitude,capacity)
values (1,'Central Square', 41.4036, 2.1740,6000),
       (2,'Park Street', 42.4050,2.1800,4500);

insert into tunnel (pk_tunnel_tunnel_id,fk_tunnel_start_station_id, fk_tunnel_end_station_id)
values (1, 1,2),
	   (2,1,2);

insert into track (pk_track_track_id,fk_track_start_station_id, fk_track_end_station_id,direction)
values (1,1,2,'bi-directional'),
	   (2,1,2,'bi-directional');

insert into object_maintenance (fK_object_maintenance_maintenance_id,fK_object_maintenance_train_id,fK_object_maintenance_track_id,
fK_object_maintenance_station_id,fK_object_maintenance_tunnel_id, start_date,end_date,cost,description)
values (1,1,2,2,1,'2000-01-15','2000-01-21',350.00,'Brake pads replaced'),
       (2,1,1,2,2,'2000-02-10','2000-01-19',510.00,'Rail grinding')
on conflict do nothing;

insert into line_station (pk_line_station_line_station_id,fk_line_station_line_id,fk_line_station_station_id,sequence_number)
values (1,2,1,2),
	   (2,1,2,1) 
on conflict do nothing;	   

insert into train_line_assignment (fk_train_line_assignment_train_id,fk_train_line_assignment_line_id, start_date,end_date)
values (1,2,'2000-01-20','2000-02-01'),
       (2,1,'2000-02-08','2000-02-19')
       on conflict do nothing;

insert into train_schedule(fk_train_schedule_train_id,fk_train_schedule_station_id, fk_train_schedule_line_station_id,arrival_datetime,departure_datetime)
values (1,2,2,'2000-01-10','2000-01-20'), 
       (2,2,1,'2000-02-02','2000-02-10')
       on conflict do nothing;

insert into ticket(pk_ticket_ticket_id,ticket_type,price)
values (1,'single',10.00),
       (2,'day pass',17.00)
       on conflict do nothing;

insert into promotion (pk_promotion_promotion_id,promotion_name,start_date,end_date,discount_amount)
values (1,'Spring sale','2000-01-05','2000-01-15',0.50),
       (2,'Weeekend deal','2000-02-05','2000-02-15', 1.00)
       on conflict do nothing;

insert into transaction_table (fk_transaction_table_ticket_id,fk_transaction_table_promotion_id,fk_transaction_table_station_id,quantity,purchase_datetime)
values(1,2,1,4,'2000-01-10'),
      (2,2,1,6,'2000-01-11')
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
