{{ config(
    materialized = 'table',
    partition_by = {
      "field": "pickup_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by = ["hour_of_day"]
)}}

-- Hourly aggregation for time-of-day analysis
SELECT
    dt.year,
    dt.month,
    dt.day,
    dt.hour AS hour_of_day,
    DATE(dt.datetime_timestamp) AS pickup_date,
    COUNT(*) AS trip_count,
    AVG(t.trip_distance) AS avg_distance,
    AVG(t.fare_amount) AS avg_fare,
    AVG(t.tip_amount) AS avg_tip,
    AVG(t.total_amount) AS avg_total,
    SUM(t.total_amount) AS total_revenue,
    dt.is_weekend
FROM
    {{ ref('fact_trips') }} t
JOIN
    {{ ref('dim_datetime') }} dt ON t.pickup_datetime_id = dt.datetime_id
GROUP BY
    dt.year, dt.month, dt.day, dt.hour, pickup_date, dt.is_weekend
ORDER BY
    dt.year, dt.month, dt.day, dt.hour