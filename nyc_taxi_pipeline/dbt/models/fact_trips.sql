{{ config(
    materialized = 'table',
    partition_by = {
      "field": "pickup_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by = ["pickup_location_id"]
)}}

WITH trips_with_datetime_ids AS (
    SELECT
        -- Generate a unique trip ID
        FORMAT('%s_%s', 
            FORMAT_TIMESTAMP('%Y%m%d%H%M%S', tpep_pickup_datetime),
            CAST(FARM_FINGERPRINT(CONCAT(
                CAST(VendorID AS STRING),
                CAST(tpep_pickup_datetime AS STRING),
                CAST(PULocationID AS STRING),
                CAST(DOLocationID AS STRING)
            )) AS STRING)
        ) AS trip_id,
        
        -- Link to datetime dimension
        FORMAT_TIMESTAMP('%Y%m%d%H', tpep_pickup_datetime) AS pickup_datetime_id,
        FORMAT_TIMESTAMP('%Y%m%d%H', tpep_dropoff_datetime) AS dropoff_datetime_id,
        
        -- Link to zones dimension
        PULocationID AS pickup_location_id,
        DOLocationID AS dropoff_location_id,
        
        -- Trip data
        passenger_count,
        trip_distance,
        fare_amount,
        tip_amount,
        total_amount,
        
        -- Additional columns for partitioning and analysis
        DATE(tpep_pickup_datetime) AS pickup_date,
        TIMESTAMP_DIFF(tpep_dropoff_datetime, tpep_pickup_datetime, MINUTE) AS trip_duration_minutes
        
    FROM
        {{ source('nyc_taxi', 'yellow_tripdata') }}
    WHERE
        -- Basic data quality filters
        tpep_pickup_datetime IS NOT NULL
        AND tpep_dropoff_datetime IS NOT NULL
        AND tpep_dropoff_datetime > tpep_pickup_datetime
        AND trip_distance > 0
        AND total_amount > 0
)

SELECT * FROM trips_with_datetime_ids