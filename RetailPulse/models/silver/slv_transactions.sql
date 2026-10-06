WITH transactions AS (
    SELECT
        RAW_DATA:transaction_id::STRING AS transaction_id,
        RAW_DATA:customer_info.id::STRING AS customer_id,
        RAW_DATA:customer_info.country::STRING AS country,
        TRY_TO_DECIMAL(RAW_DATA:total_amount::STRING, 18, 2) AS total_amount,
        TRY_TO_TIMESTAMP_TZ(RAW_DATA:event_timestamp::STRING) AS event_timestamp,
        RAW_DATA:items AS items
    FROM {{ source('bronze', 'BRZ_TRANSACTIONS') }}
)

SELECT
    t.transaction_id,
    t.customer_id,
    t.country,
    t.total_amount,
    t.event_timestamp,
    COUNT(item.value) AS item_count
FROM transactions AS t,
     LATERAL FLATTEN(INPUT => t.items, OUTER => TRUE) AS item
GROUP BY
    t.transaction_id,
    t.customer_id,
    t.country,
    t.total_amount,
    t.event_timestamp