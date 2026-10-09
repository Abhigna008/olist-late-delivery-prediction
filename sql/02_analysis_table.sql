SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,
    c.customer_state
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


SELECT is_late, COUNT(*)
FROM (
SELECT o.order_id, c.customer_state, o.order_purchase_timestamp AS purchase_ts, 
-- how many days delivery was promised to take
(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date) AS estimated_days,
-- how many days it actually took to deliver
(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS actual_delivery_days,
-- if the order delivered was late or on time to the customer
(o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)::int AS is_late
 FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
) t
GROUP BY is_late;

Select oi.order_id, COUNT(*) AS total_numb_of_items, 
SUM(p.product_weight_g) AS total_weight_of_items_in_grams,
COUNT(DISTINCT oi.seller_id) AS total_sellers, SUM(oi.price) AS total_order_price,
SUM(oi.freight_value) AS total_shipping_cost FROM order_items oi
LEFT JOIN products p
ON p.product_id = oi.product_id
group by oi.order_id;

WITH items AS (
Select oi.order_id, COUNT(*) AS total_numb_of_items, 
SUM(p.product_weight_g) AS total_weight_of_items_in_grams,
COUNT(DISTINCT oi.seller_id) AS total_sellers, SUM(oi.price) AS total_order_price,
SUM(oi.freight_value) AS total_shipping_cost FROM order_items oi
LEFT JOIN products p
ON p.product_id = oi.product_id
group by oi.order_id
)
SELECT o.order_id, i.total_numb_of_items, i.total_weight_of_items_in_grams,
o.order_purchase_timestamp, 
(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date) AS estimated_days,
-- how many days it actually took to deliver
(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS actual_delivery_days,
-- if the order delivered was late or on time to the customer
(o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)::int AS is_late,
i.total_sellers, i.total_order_price, i.total_shipping_cost,
c.customer_state FROM orders o 
JOIN customers c ON c.customer_id = o.customer_id
JOIN items i ON i.order_id = o.order_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;

SELECT * FROM (
select oi.order_id, oi.order_item_id, COALESCE(pct.product_category_name_english, 'UNKNOWN') AS product_category,
oi.seller_id, s.seller_state, oi.product_id, oi.price,
ROW_NUMBER() OVER(PARTITION BY oi.order_id ORDER BY oi.price DESC, oi.order_item_id) row_numb
FROM order_items oi
LEFT JOIN products p
ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation pct
ON pct.product_category_name = p.product_category_name
LEFT JOIN sellers s
ON s.seller_id = oi.seller_id
) t
WHERE row_numb = 1;

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
oi.seller_id, s.seller_state, oi.product_id, oi.price,
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
)
SELECT o.order_id, i.total_numb_of_items, i.total_weight_of_items_in_grams,
o.order_purchase_timestamp, 
(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date) AS estimated_days,
-- how many days it actually took to deliver
(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS actual_delivery_days,
-- if the order delivered was late or on time to the customer
(o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)::int AS is_late,
i.total_sellers, i.total_order_price, i.total_shipping_cost,
c.customer_state, mi.seller_state, mi.product_category, 
(c.customer_state = mi.seller_state)::int AS same_state,
FROM orders o 
JOIN customers c ON c.customer_id = o.customer_id
JOIN items i ON i.order_id = o.order_id
JOIN main_items mi on mi.order_id = o.order_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;