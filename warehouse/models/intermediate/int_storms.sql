-- one row per Atlantic storm, with peak intensity and Saffir-Simpson category
select
    storm_id,
    any_value(storm_name) as storm_name,
    any_value(season) as season,
    min(observed_at) as first_observed_at,
    max(observed_at) as last_observed_at,
    max(max_wind_kt) as peak_wind_kt,
    min(min_pressure_mb) as min_pressure_mb,
    case
        when max(max_wind_kt) >= 137 then 5
        when max(max_wind_kt) >= 113 then 4
        when max(max_wind_kt) >= 96 then 3
        when max(max_wind_kt) >= 83 then 2
        when max(max_wind_kt) >= 64 then 1
        else 0
    end as peak_category,  -- 0 = tropical storm or weaker
    count(*) as track_points
from {{ ref('stg_noaa__track_points') }}
group by storm_id
