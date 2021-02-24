create database sales_delivery;
select * from cust_dimen;
select * from market_fact;
select * from orders_dimen1 ;
select * from prod_dimen;
select * from shipping_dimen;


create table combined_table1
select * from market_fact a left join cust_dimen b using(cust_id)
left join orders_dimen1 c using(ord_id) 
left join prod_dimen d using(prod_id);

create table combined_table
select f.*,ship_mode,Ship_Date from combined_table1 f
left join shipping_dimen g on  f.Order_ID=g.Order_ID and f.ship_id=g.ship_id ;

select * from combined_table;

-- Find the top 3 customers who have the maximum number of orders
select distinct cust_id,Customer_name,count(distinct ord_id) order_count from cust_dimen
 join market_fact using(Cust_id) 
 join orders_dimen1 using(Ord_id)
 group by cust_id order by count(distinct ord_id) desc limit 3;
 
 
select distinct cust_id,Customer_name,count(distinct ord_id) order_count from combined_table 
group by cust_id order by order_count desc limit 3;


-- Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.
create table final as 
select * from combined_table join (
select ord_id,datediff(ship_date,order_date) DaysTakenForDelivery from orders_dimen1
left join shipping_dimen using(order_id) group by ord_id)t using (ord_id);

select * from final;

-- Find the customer whose order took the maximum time to get delivered
select customer_name,ord_id,datediff(ship_date,order_date) DaysTakenForDelivery from combined_table
group by ord_id order by DaysTakenForDelivery desc limit 1;


-- Retrieve total sales made by each product from the data (use Windows function)
select distinct prod_id,sum(sales) over(partition by prod_id order by prod_id) total_sales from combined_table ;


-- Retrieve total profit made from each product from the data (use windows function)
select * from
(select distinct prod_id,
sum(profit) over(partition by prod_id) total_profit from combined_table )t 
where total_profit>0 order by prod_id;

-- Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
select month(order_date) month_of_yr,
count(distinct cust_id)  total_unique_cust
from combined_table where year(order_date)=2011 and cust_id in(
select distinct cust_id
from combined_table where month(order_date)=1 and year(order_date)=2011) group by month_of_yr order by month(order_date);


-- Retrieve month-by-month customer retention rate since the start of the business.(using views)
-- Tips:
#1: Create a view where each user’s visits are logged by month, allowing for the possibility that these will have occurred over multiple 
# years since whenever business started operations

Create view V1 AS 
	SELECT cust_id, TIMESTAMPDIFF(month,'2009-01-01', order_date) AS visit_month
	FROM combined_table
	GROUP BY 1,2
	ORDER BY 1,2;

/*
create or replace view v1 as 
select cust_id,floor(datediff(order_date,'2009-01-01')/30) visit_month
from combined_TABLE 
group by 1,2 
order by 1,2;
(this method gives lesser rows since we are not taking exact difference)
*/
select * from v1;

# 2: Identify the time lapse between each visit. So, for each person and for each month, we see when the next visit is.
 create view time_lapse as
	SELECT distinct cust_id, 
					visit_month, 
					lead(visit_month) over(
					partition BY cust_id) next_visit
	FROM v1;
select * from time_lapse;

# 3: Calculate the time gaps between visits
create view time_gap as
SELECT cust_id,
           visit_month,
           next_visit,
           next_visit - visit_month AS time_diff 
	from Time_Lapse;
select * from time_gap;

# 4: categorise the customer with time gap 1 as retained, >1 as irregular and NULL as churned
create view v2 as
SELECT cust_id,
       visit_month,
       CASE
             WHEN time_diff=1 THEN "retained"
             WHEN time_diff>1 THEN "irregular"
             WHEN time_diff IS NULL THEN "churned"
       END as cust_category
FROM time_gap;


# 5: calculate the retention month wise
create view final_view as
SELECT visit_month,round((COUNT(if (cust_category="retained",1,NULL))/COUNT(cust_id))*100,2) AS retention_percent
FROM v2  GROUP BY 1 order by visit_month;

select * from final_view;

