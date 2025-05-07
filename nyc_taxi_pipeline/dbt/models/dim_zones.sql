{{ config(
    materialized = 'table'
)}}

-- For the MVP, we'll create a simplified zone dimension
-- In a real project, you would load the actual taxi zone lookup table

WITH pickup_zones AS (
    SELECT DISTINCT
        PULocationID as location_id
    FROM
        {{ source('nyc_taxi', 'yellow_tripdata') }}
),

dropoff_zones AS (
    SELECT DISTINCT
        DOLocationID as location_id
    FROM
        {{ source('nyc_taxi', 'yellow_tripdata') }}
),

all_zones AS (
    SELECT location_id FROM pickup_zones
    UNION DISTINCT
    SELECT location_id FROM dropoff_zones
),

-- For the MVP, we'll create dummy zone data
-- In a real project, you would join with the taxi zone lookup table
zone_mapping AS (
    SELECT
        location_id,
        CASE
            WHEN location_id BETWEEN 1 AND 50 THEN 'Manhattan'
            WHEN location_id BETWEEN 51 AND 100 THEN 'Brooklyn'
            WHEN location_id BETWEEN 101 AND 150 THEN 'Queens'
            WHEN location_id BETWEEN 151 AND 200 THEN 'Bronx'
            ELSE 'Staten Island'
        END AS borough,
        CONCAT('Zone ', CAST(location_id AS STRING)) AS zone
    FROM
        all_zones
)

SELECT * FROM zone_mapping