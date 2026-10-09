select
    county_fips,
    regexp_replace(county_name, ' County$', '') as county_name,
    {{ county_key('county_name') }} as county_key,
    land_sqmi::double as land_sqmi,
    water_sqmi::double as water_sqmi,
    lat::double as lat,
    lon::double as lon
from {{ source('census', 'county_centroids') }}
