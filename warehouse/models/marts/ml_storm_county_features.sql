-- training set for "will this county get FEMA Individual Assistance for this storm?"
-- grain: storm × county, for storms since 2000 that came within 300 km of the county.
with matched as (
    select m.storm_id, dc.county_fips,
           bool_or(dc.individual_assistance_declared) as ia_declared,
           sum(dc.ihp_amount) as ihp_amount
    from {{ ref('int_disaster_storm_match') }} m
    join {{ ref('fct_disaster_county') }} dc using (disaster_number)
    group by all
)

select
    e.storm_id || '-' || e.county_fips as storm_county_key,
    e.storm_id,
    s.storm_name,
    s.season,
    e.county_fips,
    c.county_name,
    -- storm features
    s.peak_wind_kt as storm_peak_wind_kt,
    e.min_distance_km,
    e.wind_at_closest_kt,
    coalesce(e.max_wind_within_100km_kt, 0) as max_wind_within_100km_kt,
    coalesce(e.max_wind_within_200km_kt, 0) as max_wind_within_200km_kt,
    e.hours_within_200km,
    e.landfall_within_100km,
    -- county features
    ln(c.population) as log_population,
    c.water_sqmi / (c.land_sqmi + c.water_sqmi) as water_share,  -- rough coastal/wetland proxy
    -- label
    coalesce(matched.ia_declared, false) as ia_declared,
    coalesce(matched.ihp_amount, 0) as ihp_amount
from {{ ref('int_storm_county_exposure') }} e
join {{ ref('int_storms') }} s using (storm_id)
join {{ ref('dim_county') }} c using (county_fips)
left join matched using (storm_id, county_fips)
where s.season >= 2000 and e.min_distance_km <= 300
