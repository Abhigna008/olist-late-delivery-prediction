DROP TABLE IF EXISTS order_analysis;

CREATE TABLE order_analysis AS 
WITH items AS (
Select oi.order_id, COUNT(*) AS total_numb_of_items, 
SUM(p.product_weight_g) AS total_weight_of_items_in_grams,
COUNT(DISTINCT oi.seller_id) AS total_sellers, SUM(oi.price) AS total_order_price,
SUM(oi.freight_value) AS total_shipping_cost FROM order_items oi
LEFT JOIN products p
ON p.product_id = oi.product_id
group by oi.order_id
), 
main_items AS(
SELECT * FROM (
select oi.order_id, oi.order_item_id, COALESCE(pct.product_category_name_english, 'UNKNOWN') AS product_category,
oi.seller_id, s.seller_state, oi.product_id, oi.price, s.seller_zip_code_prefix,
ROW_NUMBER() OVER(PARTITION BY oi.order_id ORDER BY oi.price DESC, oi.order_item_id) row_numb
FROM order_items oi
LEFT JOIN products p
ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation pct
ON pct.product_category_name = p.product_category_name
LEFT JOIN sellers s
ON s.seller_id = oi.seller_id
) t
WHERE row_numb = 1
), 
payments AS(
select order_id, SUM(payment_value) AS total_payment, MAX(payment_installments) AS max_installments,
(ARRAY_AGG(payment_type order by payment_value DESC))[1] AS main_payment_type FROM order_payments
group by order_id
),
reviews AS(
select order_id, ROUND(AVG(review_score),2) AS review_rating from order_reviews
group by order_id
),
geo AS(
select geolocation_zip_code_prefix as zip, AVG(geolocation_lat) AS lat, AVG(geolocation_lng) as lng
from geolocation
where geolocation_lat between -34 AND 6
AND geolocation_lng between -74 AND -34
group by zip
)
SELECT o.order_id, i.total_numb_of_items, i.total_weight_of_items_in_grams,
o.order_purchase_timestamp, 
(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date) AS estimated_days,
-- how many days it actually took to deliver
(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS actual_delivery_days,
-- if the order delivered was late or on time to the customer
(o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)::int AS is_late,
i.total_sellers, i.total_order_price, i.total_shipping_cost,
c.customer_state, c.customer_zip_code_prefix, mi.seller_state, mi.seller_zip_code_prefix, mi.product_category, mi.seller_id,
(c.customer_state = mi.seller_state)::int AS same_state, 
pay.total_payment, pay.max_installments, pay.main_payment_type, rev.review_rating, 
ROUND((2 * 6371 * ASIN(SQRT(
      POWER(SIN(RADIANS(sg.lat - cg.lat) / 2), 2)
    + COS(RADIANS(cg.lat)) * COS(RADIANS(sg.lat))
    * POWER(SIN(RADIANS(sg.lng - cg.lng) / 2), 2)
)))::numeric, 1) AS distance_km
FROM orders o 
JOIN customers c ON c.customer_id = o.customer_id
JOIN items i ON i.order_id = o.order_id
JOIN main_items mi on mi.order_id = o.order_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
LEFT JOIN reviews rev ON rev.order_id = o.order_id
LEFT JOIN geo cg ON cg.zip = c.customer_zip_code_prefix
LEFT JOIN geo sg ON sg.zip = mi.seller_zip_code_prefix
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;

ALTER TABLE order_analysis ADD PRIMARY KEY (order_id);

-- Query 1: “Do late orders get worse reviews than on-time orders?”
SELECT CASE WHEN is_late = 0 THEN 'Arrived on time' ELSE 'Arrived late' END AS order_arrival_status,
COUNT(*) AS orders, ROUND(AVG(review_rating), 2) AS avg_rating, 
ROUND((AVG((review_rating <= 2)::int) * 100),2) AS pct_bad_review
FROM order_analysis
group by order_arrival_status;

-- Query 2: “Which customer states have the highest late rate?”
SELECT customer_state, SUM(is_late) AS total_late_orders, COUNT(*) AS orders,
ROUND((AVG(is_late) * 100),2) AS rate_of_late_order_arrival
from order_analysis
group by customer_state
having count(*) >= 100
order by rate_of_late_order_arrival DESC;

-- Query 3: “Which product categories are late most often?”
Select product_category, SUM(is_late) AS total_late_orders, COUNT(*) AS orders,
ROUND((AVG(is_late) * 100),2) AS late_arrival_percentage
from order_analysis
group by product_category
having count(*) >= 200
order by late_arrival_percentage desc
limit 10;

-- Query 4: “Is there seasonality?” (late rate by month)
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS months, SUM(is_late) AS total_late_orders, 
COUNT(*) AS orders,
ROUND((AVG(is_late) * 100),2) AS late_arrival_percentage
from order_analysis
group by months
having count(*) >= 100
order by months;

SELECT * FROM order_analysis LIMIT 10;

-- Query 5: “Which sellers are late most often?"
select seller_id, seller_state, SUM(is_late) AS total_late_orders, 
COUNT(*) AS orders,
ROUND((AVG(is_late) * 100),2) AS late_arrival_percentage
from order_analysis
group by seller_id, seller_state
having count(*) >= 50
order by late_arrival_percentage desc
limit 10;