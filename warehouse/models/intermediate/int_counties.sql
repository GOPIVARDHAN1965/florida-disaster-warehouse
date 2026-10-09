with pop as (
    select county_fips, population
    from {{ ref('stg_census__county_population') }}
    qualify row_number() over (partition by county_fips order by year desc) = 1
)

select
    c.county_fips,
    c.county_name,
    c.county_key,
    c.lat,
    c.lon,
    c.land_sqmi,
    c.water_sqmi,
    pop.population
from {{ ref('stg_census__county_centroids') }} c
left join pop using (county_fips)
