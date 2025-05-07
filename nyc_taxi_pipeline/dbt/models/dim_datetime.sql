{{ config(
    materialized='table',
    partition_by={
      "field": "datetime_id",
      "data_type": "date",
      "granularity": "day"
    }
)}}

WITH datetime_spine AS (
    SELECT
        DISTINCT DATE(tpep_pickup_datetime) AS date
    FROM
        {{ source('nyc_taxi', 'yellow_tripdata') }}
    
    UNION DISTINCT
    
    SELECT
        DISTINCT DATE(tpep_dropoff_datetime) AS date
    FROM
        {{ source('nyc_taxi', 'yellow_tripdata') }}
),

hours AS (
    SELECT * FROM UNNEST(GENERATE_ARRAY(0, 23)) AS hour
),

datetime_expanded AS (
    SELECT
        date,
        hour
    FROM
        datetime_spine
    CROSS JOIN
        hours
),

final AS (
    SELECT
        FORMAT_TIMESTAMP('%Y%m%d%H', TIMESTAMP(date) + INTERVAL hour HOUR) AS datetime_id,
        hour,
        EXTRACT(DAY FROM date) AS day,
        EXTRACT(MONTH FROM date) AS month,
        EXTRACT(YEAR FROM date) AS year,
        EXTRACT(DAYOFWEEK FROM date) AS weekday,
        CASE 
            WHEN EXTRACT(DAYOFWEEK FROM date) IN (1, 7) THEN TRUE 
            ELSE FALSE 
        END AS is_weekend,
        TIMESTAMP(date) + INTERVAL hour HOUR AS datetime_timestamp
    FROM
        datetime_expanded
)

SELECT * FROM final