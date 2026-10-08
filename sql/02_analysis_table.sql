select * from orders limit 10;

select * from customers limit 10;

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