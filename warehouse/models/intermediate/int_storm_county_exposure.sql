-- how close, how strong and how long each storm came to each Florida county (centroid-based).
-- Only storm × county pairs within 500 km are kept.
with points as (
    select * from {{ ref('stg_noaa__track_points') }}
    -- coarse box around Florida keeps the cross join small
    where lat between 20 and 36 and lon between -92 and -74
),

pairs as (
    select
        p.storm_id,
        c.county_fips,
        p.observed_at,
        p.max_wind_kt,
        p.is_landfall,
        {{ haversine_km('p.lat', 'p.lon', 'c.lat', 'c.lon') }} as distance_km
    from points p
    cross join {{ ref('int_counties') }} c
)

select
    storm_id,
    county_fips,
    min(distance_km) as min_distance_km,
    arg_min(max_wind_kt, distance_km) as wind_at_closest_kt,
    arg_min(observed_at, distance_km) as closest_approach_at,
    max(max_wind_kt) filter (where distance_km <= 100) as max_wind_within_100km_kt,
    max(max_wind_kt) filter (where distance_km <= 200) as max_wind_within_200km_kt,
    6 * count(*) filter (where distance_km <= 200) as hours_within_200km,
    bool_or(is_landfall and distance_km <= 100) as landfall_within_100km
from pairs
group by storm_id, county_fips
having min(distance_km) <= 500
