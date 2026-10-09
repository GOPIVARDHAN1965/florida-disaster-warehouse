select
    storm_id,
    nullif(storm_name, 'UNNAMED') as storm_name,
    right(storm_id, 4)::int as season,
    strptime(obs_date || obs_time, '%Y%m%d%H%M') as observed_at,
    record_id = 'L' as is_landfall,
    status,  -- HU hurricane, TS tropical storm, TD depression, EX extratropical...
    lat::double as lat,
    lon::double as lon,
    nullif(max_wind_kt::int, -999) as max_wind_kt,
    nullif(min_pressure_mb::int, -999) as min_pressure_mb
from {{ source('noaa', 'hurdat2_tracks') }}
