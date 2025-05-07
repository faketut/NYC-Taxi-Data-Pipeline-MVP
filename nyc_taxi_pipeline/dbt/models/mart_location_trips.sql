{{ config(
    materialized = 'table',
    cluster_by = ["pickup_location_id", "borough"]
)}}

-- Location aggregation for categorical dashboard tile
SELECT
    t.pickup_location_id,
    z.borough,
    z.zone,
    COUNT(*) AS trip_count,
    AVG(t.trip_distance) AS avg_distance,
    AVG(t.fare_amount) AS avg_fare,
    AVG(t.tip_amount) AS avg_tip,
    AVG(t.total_amount) AS avg_total,
    SUM(t.total_amount) AS total_revenue
FROM
    {{ ref('fact_trips') }} t
JOIN
    {{ ref('dim_zones') }} z ON t.pickup_location_id = z.location_id
GROUP BY
    t.pickup_location_id, z.borough, z.zone
ORDER BY
    trip_count DESC