USE pizza_runner;

SELECT * FROM runners;

SELECT * FROM runner_orders;

SELECT * FROM customer_orders;

SELECT * FROM pizza_names;

SELECT * FROM pizza_recipes;

SELECT * FROM pizza_toppings;

/* Data cleaning and data transformation */

SELECT order_id, customer_id, pizza_id, 
  CASE 
    WHEN exclusions IS	NULL OR exclusions LIKE 'null' THEN ' '
    ELSE exclusions
    END AS exclusions,
  CASE 
    WHEN extras IS NULL or extras LIKE 'null' THEN ' '
    ELSE extras 
    END AS extras, 
  order_time
  INTO customer_orders_temp -- create TEMP TABLE
FROM customer_orders;

SELECT * FROM customer_orders;
SELECT * FROM customer_orders_temp;

SELECT order_id, runner_id,
  CASE 
    WHEN pickup_time LIKE 'null' THEN ' '
    ELSE pickup_time 
    END AS pickup_time,
  CASE 
    WHEN distance LIKE 'null' THEN ' '
    WHEN distance LIKE '%km' THEN TRIM('km' from distance) 
    ELSE distance END AS distance,
  CASE 
    WHEN duration LIKE 'null' THEN ' ' 
    WHEN duration LIKE '%mins' THEN TRIM('mins' from duration) 
    WHEN duration LIKE '%minute' THEN TRIM('minute' from duration) 
    WHEN duration LIKE '%minutes' THEN TRIM('minutes' from duration)       
    ELSE duration END AS duration,
  CASE 
    WHEN cancellation IS NULL or cancellation LIKE 'null' THEN ''
    ELSE cancellation END AS cancellation
INTO runner_orders_temp
FROM runner_orders;

SELECT * FROM runner_orders
SELECT * FROM runner_orders_temp

ALTER TABLE runner_orders_temp
ALTER COLUMN pickup_time DATETIME;
ALTER TABLE runner_orders_temp
ALTER COLUMN distance FLOAT;
ALTER TABLE runner_orders_temp
ALTER COLUMN duration INT;

/* pizza metrics */

/* How many pizzas were ordered? */

SELECT COUNT(*) AS pizza_order_count
FROM customer_orders_temp;

/* How many unique customer orders were made? */

SELECT COUNT(DISTINCT order_id) AS unique_customer_count
FROM customer_orders_temp;

/* How many successful orders were delivered by each runner? */

SELECT runner_id, COUNT(order_id) AS successful_order_count
FROM runner_orders_temp 
WHERE distance != 0
GROUP BY runner_id;

/* How many of each type of pizza was delivered?*/

ALTER TABLE pizza_names
ALTER COLUMN pizza_name VARCHAR(10);

SELECT C.pizza_id,pizza_name, COUNT(*) AS pizza_count
FROM customer_orders_temp AS C  
JOIN runner_orders_temp AS R
ON C.order_id= R.order_id
JOIN pizza_names AS P
ON C.pizza_id = P.pizza_id
WHERE distance != 0
GROUP BY C.pizza_id,pizza_name;

/* How many Vegetarian and Meatlovers were ordered by each customer? */

SELECT customer_id, pizza_name,COUNT(*) AS pizza_count
FROM customer_orders_temp AS C
JOIN pizza_names AS P
ON C.pizza_id=P.pizza_id
GROUP BY customer_id,pizza_name
ORDER BY customer_id ASC ;

/* What was the maximum number of pizzas delivered in a single order? */

  WITH max_pizza AS 
 (
   SELECT cust.order_id,COUNT(cust.pizza_id) AS pizza_per_order
   FROM customer_orders_temp AS cust
   JOIN runner_orders_temp AS run
   ON cust.order_id = run.order_id
   GROUP BY cust.order_id
 )
  SELECT MAX(pizza_per_order) AS pizza_count 
  FROM max_pizza

/* For each customer, how many delivered pizzas had at least 1 change and how many had no changes? */

  SELECT c.customer_id,
  SUM (
      CASE WHEN c.exclusions != ' ' OR c.extras != ' ' THEN 1 ELSE 0 END 
	  ) AS change_1,
  SUM (
      CASE WHEN c.exclusions = ' ' AND c.extras = ' ' THEN 1 ELSE 0 END
	  ) AS no_change
    FROM customer_orders_temp AS c
    JOIN runner_orders_temp AS r
	ON c.order_id = r.order_id
    WHERE r.distance != 0
    GROUP BY c.customer_id
    ORDER BY c.customer_id;

/* How many pizzas were delivered that had both exclusions and extras? */

	SELECT COUNT(*) AS pizza_having_exclusions_n_extras
    FROM customer_orders_temp AS c
    JOIN runner_orders_temp AS r
	ON c.order_id = r.order_id
    WHERE r.distance != 0
    AND exclusions != ' ' 
	AND extras != ' ';

/* What was the total volume of pizzas ordered for each hour of the day? */

	SELECT DATEPART(HOUR, [order_time]) AS hour_of_day, 
    COUNT(order_id) AS pizza_count
    FROM customer_orders_temp
    GROUP BY DATEPART(HOUR, [order_time]);

 /* How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01) */

   SELECT DATEPART(week, registration_date) AS registration_week,
   COUNT(*) AS runner_signup
   FROM runners
   GROUP BY DATEPART(week, registration_date);

 /* What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order? */
   
  WITH time_taken AS
  (
    SELECT c.order_id,r.runner_id,
	c.order_time,r.pickup_time,
	 DATEDIFF(minute,c.order_time,r.pickup_time) AS pickup_minutes
	 FROM customer_orders_temp AS c
	 JOIN runner_orders_temp AS r
	 ON c.order_id = r. order_id
	 WHERE r.distance != 0
	 GROUP BY r.runner_id,c.order_id,c.order_time,r.pickup_time
  )
    SELECT runner_id, AVG(pickup_minutes) AS pickup_avg_minutes
	FROM time_taken
	GROUP BY runner_id;

  /* Is there any relationship between the number of pizzas and how long the order takes to prepare? */
    
	 WITH prepare_time AS
  (
    SELECT c.order_id,
	 COUNT (c.order_id) AS pizza_order,
	 c.order_time,r.pickup_time,
	 DATEDIFF(minute,c.order_time,r.pickup_time) AS prepare_time_min
	 FROM customer_orders_temp AS c
	 JOIN runner_orders_temp AS r
	 ON c.order_id = r. order_id
	 WHERE r.distance != 0
	 GROUP BY c.order_id,c.order_time,r.pickup_time
   )
	SELECT pizza_order, AVG(prepare_time_min) AS avg_prepare_time_min
	FROM prepare_time
	GROUP BY pizza_order;

 /* What was the average distance travelled for each customer? */

    SELECT customer_id, ROUND(AVG(distance),1) AS avg_distance
	FROM customer_orders_temp AS c
	JOIN runner_orders_temp AS r
	 ON c.order_id= r.order_id
	WHERE distance != 0
	GROUP BY customer_id;

 /* What was the difference between the longest and shortest delivery times for all orders? */

   SELECT MAX(duration) - MIN(duration) as delivery_difference_time
   FROM runner_orders_temp
   WHERE distance != 0;

 /* What was the average speed for each runner for each delivery and do you notice any trend for these values? */

   SELECT runner_id,order_id,ROUND(AVG(60*(distance/duration)),1) AS speed
   FROM runner_orders_temp
   WHERE distance!=0
   GROUP BY runner_id,order_id
   ORDER BY runner_id;

 /* What is the successful delivery percentage for each runner? */


   SELECT runner_id, 
   ROUND(100 * SUM
    (CASE WHEN distance = 0 THEN 0
     ELSE 1
    END) / COUNT(*), 0) AS successful_percent
   FROM runner_orders_temp
   GROUP BY runner_id;
