-- =====================================================================
-- Olist E-Commerce Dataset: PostgreSQL setup
-- Creates 9 tables, loads the CSVs, adds keys, and checks row counts.
--
-- HOW TO RUN (in SQL Shell / psql, NOT the pgAdmin Query Tool):
--   1. Put all 9 CSV files + this script in  D:/Data_Analytics/youtube/4 predictive analysis/olist_data/
--   2. In psql:   CREATE DATABASE olist;
--                 \c olist
--                 \i 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_setup.sql'
--   If your files are in another folder, find & replace "D:/Data_Analytics/youtube/4 predictive analysis/olist_data/"
--   below with your folder path (use forward slashes /).
-- =====================================================================

SET client_encoding = 'UTF8';

-- ---------- Clean start (lets you re-run the script safely) ----------
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
    customers, products, sellers, geolocation,
    product_category_name_translation CASCADE;

-- ------------------------------ Tables -------------------------------
CREATE TABLE customers (
    customer_id               VARCHAR(32) PRIMARY KEY,
    customer_unique_id        VARCHAR(32) NOT NULL,   -- the real person (one person can have many customer_ids)
    customer_zip_code_prefix  INTEGER,
    customer_city             TEXT,
    customer_state            CHAR(2)
);

CREATE TABLE geolocation (                            -- no primary key: zip prefixes repeat by design
    geolocation_zip_code_prefix  INTEGER,
    geolocation_lat              DOUBLE PRECISION,
    geolocation_lng              DOUBLE PRECISION,
    geolocation_city             TEXT,
    geolocation_state            CHAR(2)
);

CREATE TABLE sellers (
    seller_id               VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix  INTEGER,
    seller_city             TEXT,
    seller_state            CHAR(2)
);

CREATE TABLE products (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       TEXT,
    product_name_lenght         INTEGER,             -- "lenght" typo is in the original data
    product_description_lenght  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);

CREATE TABLE product_category_name_translation (
    product_category_name          TEXT PRIMARY KEY,
    product_category_name_english  TEXT
);

CREATE TABLE orders (
    order_id                       VARCHAR(32) PRIMARY KEY,
    customer_id                    VARCHAR(32),
    order_status                   TEXT,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

CREATE TABLE order_items (
    order_id             VARCHAR(32),
    order_item_id        INTEGER,                    -- 1, 2, 3... item number within the order
    product_id           VARCHAR(32),
    seller_id            VARCHAR(32),
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id              VARCHAR(32),
    payment_sequential    INTEGER,
    payment_type          TEXT,
    payment_installments  INTEGER,
    payment_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE order_reviews (                          -- no primary key: a few review_ids repeat in the source data
    review_id                VARCHAR(32),
    order_id                 VARCHAR(32),
    review_score             INTEGER,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);

-- ---------------------------- Load data ------------------------------
\copy customers                          FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_customers_dataset.csv'          WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy geolocation                        FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_geolocation_dataset.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy sellers                            FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_sellers_dataset.csv'            WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy products                           FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_products_dataset.csv'           WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy product_category_name_translation  FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy orders                             FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_orders_dataset.csv'             WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_items                        FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_order_items_dataset.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_payments                     FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_order_payments_dataset.csv'     WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_reviews                      FROM 'D:/Data_Analytics/youtube/4 predictive analysis/olist_data/olist_order_reviews_dataset.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- -------------------- Relationships (foreign keys) -------------------
ALTER TABLE orders         ADD FOREIGN KEY (customer_id) REFERENCES customers (customer_id);
ALTER TABLE order_items    ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_items    ADD FOREIGN KEY (product_id)  REFERENCES products (product_id);
ALTER TABLE order_items    ADD FOREIGN KEY (seller_id)   REFERENCES sellers (seller_id);
ALTER TABLE order_payments ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_reviews  ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);

-- ------------------- Indexes to speed up later joins -----------------
CREATE INDEX idx_reviews_order   ON order_reviews (order_id);
CREATE INDEX idx_items_product   ON order_items (product_id);
CREATE INDEX idx_items_seller    ON order_items (seller_id);
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_geo_zip         ON geolocation (geolocation_zip_code_prefix);

-- --------------------------- Sanity check ----------------------------
-- Expected: customers 99441 | geolocation 1000163 | order_items 112650
--           order_payments 103886 | order_reviews 99224 | orders 99441
--           products 32951 | sellers 3095 | translation 71
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'geolocation',    COUNT(*) FROM geolocation
UNION ALL SELECT 'order_items',    COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*) FROM order_reviews
UNION ALL SELECT 'orders',         COUNT(*) FROM orders
UNION ALL SELECT 'products',       COUNT(*) FROM products
UNION ALL SELECT 'sellers',        COUNT(*) FROM sellers
UNION ALL SELECT 'translation',    COUNT(*) FROM product_category_name_translation;
