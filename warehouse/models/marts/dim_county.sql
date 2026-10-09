select
    county_fips,
    county_name,
    lat,
    lon,
    land_sqmi,
    water_sqmi,
    population,
    population / land_sqmi as population_density
from {{ ref('int_counties') }}
