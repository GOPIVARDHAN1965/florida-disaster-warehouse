select
    county_fips,
    year::int as year,
    population::int as population
from {{ source('census', 'county_population') }}
