{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
) }}

WITH sales AS (
    SELECT
        transaction_id,
        customer_id,
        COALESCE(NULLIF(UPPER(TRIM(country)), ''), 'UNKNOWN') AS country,
        event_timestamp,
        total_amount,
        item_count,
        CASE
            WHEN item_count = 0 THEN 'sans article'
            WHEN item_count = 1 THEN 'un article'
            ELSE 'plusieurs articles'
        END AS order_category
    FROM {{ ref('slv_transactions') }}
)

SELECT
    transaction_id,
    customer_id,
    country,
    event_timestamp,
    total_amount,
    item_count,
    order_category
FROM sales

{% if is_incremental() %}
WHERE EXISTS (
    SELECT 1
    FROM {{ source('cdc', 'TRANSACTION_DELTA') }} AS delta
    WHERE delta.RAW_DATA:transaction_id::STRING = sales.transaction_id
)
AND NOT EXISTS (
    SELECT 1
    FROM {{ this }} AS existing
    WHERE existing.transaction_id = sales.transaction_id
)
{% endif %}