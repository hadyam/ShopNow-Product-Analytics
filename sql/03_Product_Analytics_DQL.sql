select count(transaction_id) as Total_Transactions
from Transactions;
----------------------------------------------
select Count(user_id) as Total_Users
from Users;
----------------------------------------------
select Count(product_id) as Total_Users
from Products;
----------------------------------------------
select Count(event_id) as Total_Users
from Events;
----------------------------------------------
select source,count(user_id) as Total_Users
from Users 
group by source
order by Total_Users;
----------------------------------------------
select u.source,COUNT(u.user_id) as Total_Users,
COUNT(t.transaction_id) AS total_transactions,
Round(sum(t.revenue),2) as Total_Revenue,
Round(AVG(t.revenue),2) as AVG_Revenue
from Users as u 
join Transactions as t
on u.user_id = t.user_id
group by u.source;
----------------------------------------------
-- Calculate the user's cumulative total spending with each new purchase, while displaying the date and value of every transaction.
select transaction_id,
user_id,revenue,transaction_time,
sum(revenue) over(partition by transaction_id order by transaction_id) as Total_Spending
from Transactions;
----------------------------------------------
-- Comparing the value of an individual transaction to the user's average spending
select transaction_id,
user_id,revenue, cast(AVG(revenue)over(partition by user_id)as decimal(12,2)) AS AVG_Transaction,
cast(revenue - AVG(revenue)over(partition by user_id)as decimal(12,2)) as "Difference"
from Transactions;
----------------------------------------------
-- Track the user's path within the application, retrieve the next event to identify their subsequent step, 
-- and calculate the time interval between that event and the preceding one to determine how much time was spent on each step.
select 
user_id,session_id, event_name , event_time,
Lead(event_name,1,'End Of Session')over(
partition by session_id
order by event_time) as Next_step,
format(
lag(event_time) over(
partition by session_id
order by event_time),'yyyy-mm-dd hh:mm:ss') AS Previous_Time,
DATEDIFF(
Second,
lag(event_time) over(
partition by session_id
order by event_time),event_time) AS 'Diffference'
from Events;
---------------------------------------------
--Numbering each user's requests from newest to oldest
select
user_id,session_id,MIN(event_time)as event_time,
Row_Number()over(
partition by user_id order by user_id) as order_recency_rank
from events
group by session_id,user_id;
---------------------------------------------
--Numbering each user's transactions from newest to oldest
SELECT 
t.user_id,
p.product_name,
Format(e.event_time,'yyyy-MM-dd HH:mm:ss') as event_time,
t.quantity,
t.revenue,
ROW_NUMBER() OVER (
PARTITION BY t.user_id 
ORDER BY e.event_time DESC
) AS order_recency_rank
FROM Transactions t
join events e
on t.event_id =e.event_id
join Products p
on t.product_id = p.product_id;
---------------------------------------------
--Calculating Funnel Drop-off
WITH FunnelSteps AS (
select 
event_name,
count(distinct(user_id))AS unique_users
from Events
group by event_name
)
select 
event_name,
unique_users,
lag(unique_users,1) over(order by unique_users DESC) as Previous_Step,
lag(unique_users,1)over(order by unique_users DESC) - unique_users AS Drop_off,
format(
(1.0 * lag(unique_users,1) over(order by unique_users  DESC)-unique_users)/
nullif(lag(unique_users,1) over(order by unique_users  DESC),0),'P1')as "Drop_Off_Percentage",
format(1.0*
unique_users / nullif(FIRST_VALUE(unique_users)over(order by unique_users DESC),0),'P1') AS Percent_Of_Total
from FunnelSteps;
-- Another way by subquery
SELECT 
event_name,
unique_users,
LAG(unique_users, 1) OVER (ORDER BY unique_users DESC) AS previous_step_users,
lag(unique_users,1)over(order by unique_users DESC) - unique_users AS Drop_off ,
Format(
(1.0*lag(unique_users,1)OVER (ORDER BY unique_users DESC)-unique_users)/
nullif(lag(unique_users,1)OVER (ORDER BY unique_users DESC),0)
,'P1') AS 'Drop_Of_Percentage',
format(
1.0*unique_users/ nullif(first_value(unique_users)over(order by unique_users DESC),0),'P1') AS Percent_Of_Total
from(
SELECT 
event_name,
COUNT(DISTINCT user_id) AS unique_users
FROM Events
GROUP BY event_name
)as bt;
---------------------------------------------
--Calculating Funnel Drop-off by device
WITH DeviceFunnelSteps AS (
select 
device_type,
event_name,
count(distinct(user_id))AS unique_users,
Case event_name
WHEN 'app_opened' THEN 1
WHEN 'product_viewed' THEN 2
WHEN 'add_to_cart' THEN 3
WHEN 'checkout_started' THEN 4
WHEN 'purchase_completed' THEN 5
end as event_num
from Events
group by event_name ,device_type
)
select 
device_type,
event_name,
unique_users,
lag(unique_users,1) over(Partition by device_type order by event_num ) as Previous_Step,
lag(unique_users,1)over(Partition by device_type order by event_num ) - unique_users AS Drop_off,
format(
(1.0 * lag(unique_users,1) over(Partition by device_type order by event_num)-unique_users)/
nullif(lag(unique_users,1) over(Partition by device_type order by event_num  ),0),'P1')as "Drop_Off_Percentage",
format(1.0*
unique_users / nullif(FIRST_VALUE(unique_users)over(Partition by device_type order by event_num),0),'P1') AS Percent_Of_Total
from DeviceFunnelSteps
ORDER BY device_type, event_num ASC;
---------------------------------------------