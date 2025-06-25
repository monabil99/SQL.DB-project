use RestaurantDatabaseSystem

--1 Total Revenue & Average Order Value 

create or alter view RevenueSummary
as
	select
	sum(PayAmount) as total_revenue,
	avg(PayAmount) as avg_order_value,
	count(ID) as total_orders
	from [Order]
	where PayAmount is not null

select * from RevenueSummary
	

--2 Total Revenue Per Mounth ( current month )

create or alter view monthly_revenue
	as
	select
    format(paydate, 'yyyy-MM') as revenue_month,
    sum(payamount) as total_revenue
	from [order]
	where payamount is not null
	group by format(paydate, 'yyyy-MM')

Select * from monthly_revenue


--3 Best selling items

create or alter view top_menu_items
	as
	select  Top(3)
		  m.name as item_name, 
	    count(o.ID) as total_sold
		from [order] o
		join Order_include_MenuItem oi on o.id = oi.Order_ID 
		inner join Menu m on oi.Item_ID = m.ItemID
		where o.PayAmount is not null
		group by m.name 
		order by m.Name desc
		

select * from top_menu_items 


--4 Best spending customers

select top 5
    c.ID,
    c.name as customer_name,
    sum(o.PayAmount) as total_spent
from customer c
join [Order] o on c.id = o.id
group by c.id, c.name
order by total_spent desc


--5 New customers per month

select 
	format(c.Created_date , 'yyyy-MM') as creat_date ,
	count( c.ID ) as new_customers
from customer c
group by format(c.Created_date , 'yyyy-MM')
order by creat_date


--6 Number of the most used tables

select top 3
    t.id as table_Number,
    count(o.id) as total_orders
from [table] t
join [order] o on t.id = o.id
group by t.id 


--7 Orders that are greater than the average order value

select 
    o.ID,
    o.PayAmount
from [Order] o
where o.PayAmount > (
    select avg(o1.PayAmount) from [Order] o1
)
order by PayAmount desc


--8 Customers with reserved tables

select c.ID as CustomerID , c.Name , t.ID as TableID
from Customer c join Customer_Reservation_Table crt
on c.ID = crt.Customer_ID 
join [Table] t on t.ID = crt.Table_ID


--9 Customers with completed orders

select c.ID as CustomerID , c.Name , o.ID as OrderID, o.PayAmount
from Customer c left join [Order] o
on c.ID = o.Customer_ID
where o.PayAmount is not null and o.Status = 'completed'
order by PayAmount asc

use RestaurantDatabaseSystem


--10 Stored Procecure return number of order for each Item  

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


--11 Stored Procecure take id customer and return number of orders as output

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


--12 Stored Procecure Calculating total revenue between two specific dates

Create or alter proc sptotalamount @start_date Date , @end_date Date
as 
begin
select sum(o.PayAmount) as Totalpayment
from [Order] o  
where o.PayDate between @start_date and @end_date
end 

execute sptotalamount '2023-01-1' , '2023-02-1'

--13 Trigger make discount 10% for customer request order than 500egp

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
 where ID= @orderid 
 end

end 

insert into [order] (PayAmount) values ( 800)

--14 Trigger for save a copy from any order deleted 

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


--15 Trigger as: If the table is reserved, prevent it from being reserved. 

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

use RestaurantDatabaseSystem


--16 Calculate the bonus and total salary for each staff member based on their salary and the company's bonus percentage policy.

create function CalculateStaffBonus(@BonusPer decimal(10,2))
returns table
as
return
	select ID, Salary, @BonusPer as BonusPer, 
	cast(Salary * @BonusPer / 100 as decimal(10,2)) as Bonus, cast(Salary + (Salary * @BonusPer / 100) as decimal(10,2)) as TotalSalary 
	from Staff

select * from CalculateStaffBonus(10)


--17 Who are the highest performing staff this month?

 create function TopPerformanceStaff(@top int)
 returns table
 as
 return
	(select Top (@top) A.ID, A.Name, A.Role, A.Salary, A.Hire_date, count(B.ID) as TotalOrders
	from Staff A join [Order] B
	on A.ID = B.Staff_ID
	where month(B.Order_Date) = month(getdate()) and year(B.Order_Date) = year(getdate())
	group by A.ID, A.Name, A.Role, A.Salary, A.Hire_date
	Order by count(B.ID) Desc)

select * from TopPerformanceStaff(3)


--18 Check Promotion Eligibility

create function PromotionEligibility(@StaffID int)
returns varchar(10)
as
begin
	declare @years int, @ordercount int, @result varchar(10)
	select @years = datediff(year, hire_date, getdate())
	from Staff
	where ID = @StaffID

	select @ordercount = count(*)
	from [Order]
	where Staff_ID = @StaffID
	if @years >= 3 and @ordercount >= 30
		set @result = 'Eligible'
	else
		set @result = 'Not Eligible'

	return @result
end

select dbo.PromotionEligibility(2)


--19 Customer Purchase Summary

create function CustomerPurchaseSummary()
returns @summary table (
CustomerID int, CustomerName varchar(30), TotalOrders int, TotalSpent decimal(10,2), FirstPurchase date, LastPurchase date)
as
begin
insert into @summary
	select A.ID as CustomerID, A.Name as CustomerName, count(B.ID) as TotalOrders , sum(B.PayAmount) as TotalSpent, 
	min(B.Order_Date) as FirstPurchase, max(B.Order_Date) as LastPurchase
    FROM Customer A
    join [Order] B ON A.ID = B.Customer_ID
    group by A.ID, A.Name
	return
end

select * from dbo.CustomerPurchaseSummary()


--20 Valid Phone Number (8 digits only)

alter table Customer_phone
add constraint phone_length
check (len(Phone) = 8)


--21 Valid Payment Method

alter table [Order]
add constraint valid_paymethod
check (PayMethod in ('Cash','Credit Card','Debit Card'))


--22 Staff Salaries View, Create Role, and Assign Permissions to 'manager_user'

create view staff_salaries_view as
select ID, name, role, salary
from staff

create role manager_role
grant select on staff_salaries_view to manager_role

use RestaurantDatabaseSystem
create login manager1 with password = 'strong_password1';

create user manager_user for login manager1
exec sp_addrolemember 'manager_role', 'manager_user'

use RestaurantDatabaseSystem


--23 Who are our top customers by spend?

SELECT Customer_ID, SUM(PayAmount) AS totalSpent, 
       DENSE_RANK() OVER (ORDER BY SUM(PayAmount) DESC) AS PaymentRank
FROM [Order]
WHERE PayAmount IS NOT NULL
GROUP BY Customer_ID


--24 What is the total order count for each customer?

SELECT c.ID, c.Name, COUNT(o.ID) AS TotalOrders,
    RANK() OVER (ORDER BY COUNT(o.ID) DESC) AS OrderRank
FROM Customer c
LEFT JOIN [Order] o ON c.ID = o.Customer_ID
GROUP BY c.ID, c.Name
ORDER BY OrderRank


--25 What are the most/least ordered menu items?

SELECT m.ItemID, m.Name AS MenuItem, COUNT(om.Order_ID) AS TotalOrders,
    DENSE_RANK() OVER (ORDER BY COUNT(om.Order_ID) DESC) AS PopularityRank FROM Menu m
JOIN Order_include_MenuItem om ON m.ItemID = om.Item_ID
GROUP BY m.ItemID, m.Name
ORDER BY PopularityRank


--26 divide customers into 4 quartiles based on their total order count

SELECT c.ID, c.Name,
    NTILE(4) OVER (ORDER BY COUNT(o.ID)) AS OrderQuartile
FROM Customer c
LEFT JOIN [Order] o ON c.ID = o.Customer_ID
GROUP BY c.ID, c.Name


--27 divide customers into 4 quartiles based on their total order payment amount

SELECT c.ID, c.Name,
    NTILE(4) OVER (ORDER BY SUM(o.PayAmount)) AS OrderQuartile
FROM Customer c
LEFT JOIN [Order] o ON c.ID = o.Customer_ID
GROUP BY c.ID, c.Name


--28 Rank Customers by Registration Date

SELECT ID, Name, Created_date, 
       RANK() OVER (ORDER BY Created_date) AS registrationRank
FROM Customer


--29 index to filter by Customer_ID and sort by Order_Date

CREATE INDEX inx_OrderCustomerID_OrderDate ON [Order](Customer_ID, Order_Date)


--30 optimizes searches for menu items by Type and Price

CREATE INDEX inx_MenuType_Price ON Menu(Type, Price)


--31 index to filter by Role and order by Salary

CREATE INDEX inx_Staff_Role_Salary ON Staff(Role, Salary)

SELECT * FROM Menu WHERE Type='Main' AND Price > 100


--32 total sales by month for each type

SELECT *
FROM ( SELECT FORMAT(Order_Date, 'yyyy-MM') AS Month, PayMethod, PayAmount
    FROM [Order]
    WHERE PayMethod IS NOT NULL ) AS SourceTable
PIVOT (
    SUM(PayAmount)
    FOR PayMethod IN ([Credit Card], [Cash], [Debit Card])
) AS PivotTable
