use RestaurantDatabaseSystem

--1 sp return number of order for each Item  
create or alter proc numItem_sp 
as
begin
select m.Name , Count(o.ID) as num_orders
from [Order] o inner join Order_include_MenuItem oi
on o.ID = oi.Order_ID  inner join Menu m
on m.ItemID = oi.Item_ID
Group by m.Name
order by num_orders desc
end

execute numItem_sp

--2-- sp take id customer and return number of orders as output

create or alter proc GetTotalOrdersByCustomer @customID int ,@totalorders int output
as
begin 
select @totalorders = count(*)
from [Order] o
where @customID = Customer_ID

end 

declare @result int
execute GetTotalOrdersByCustomer 3 , @result output
select @result


--3-SP Calculating total revenue between two specific dates

Create or alter proc sptotalamount @start_date Date , @end_date Date
as 
begin
select sum(o.PayAmount) as Totalpayment
from [Order] o  
where o.PayDate between @start_date and @end_date
end 

--4--- trigger make discount 10% for customer request order than 500egp

Create trigger discountorder 
on [order]
after insert 
as 
begin
    Declare @orderid int , @amount decimal (10,2)
  select @orderid=o.ID , @amount = o.PayAmount    from [order] o

  if @amount > 500 
 begin
 update [order] 
 set PayAmount = PayAmount* .9
 where ID= @orderid ;
 end

end 


------5 trigger---save a copy from any order deleted 

create table aduitdeleted_orders(orderid int ,customerid int, orderdate date )

create or alter trigger deletedorders 
on [Order] 
after delete
as 
begin
insert into aduitdeleted_orders (orderid,customerid, orderdate )
select ID, customer_id , Order_Date
from deleted ;
end


----6--------If the table is reserved, prevent it from being reserved. 

Create or alter trigger prevtable 
on Reservation
instead of insert 
as 
begin
 If Exists (
     select *
	 from Reservation r inner join inserted i
	 on r.ID = i.ID and r.Reservation_Date = i.reservation_date
	 ) begin
	 print ('الترابيزة محجوزة الان ');
   Rollback ;
 end

 Else
 Begin 
   Insert into Reservation(ID, Reservation_Date)
   select ID , Reservation_Date
   from inserted ;
 end
end 

