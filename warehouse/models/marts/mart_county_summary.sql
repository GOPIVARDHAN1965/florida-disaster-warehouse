-- one row per county: how often it's hit, recovery dollars vs mitigation dollars (since 2000)
with dc as (
    select
        county_fips,
        count(distinct disaster_number) filter (where individual_assistance_declared or public_assistance_declared) as major_declarations,
        sum(ihp_amount) as ihp_amount,
        sum(pa_federal_obligated) as pa_federal_obligated
    from {{ ref('fct_disaster_county') }}
    where year(declaration_date) >= 2000
    group by county_fips
),

hma as (
    select county_fips, sum(federal_share_obligated) as mitigation_federal_obligated, count(*) as mitigation_projects
    from {{ ref('fct_hma_projects') }}
    where program_fy >= 2000
    group by county_fips
),

nfip as (
    select county_fips, sum(claims) as flood_claims, sum(total_paid) as flood_claims_paid
    from {{ ref('fct_nfip_claims_county_year') }}
    where year_of_loss >= 2000
    group by county_fips
),

exposure as (
    select e.county_fips,
           count(*) filter (where e.min_distance_km <= 100 and s.peak_category >= 1) as hurricanes_within_100km
    from {{ ref('int_storm_county_exposure') }} e
    join {{ ref('int_storms') }} s using (storm_id)
    where s.season >= 2000
    group by e.county_fips
)

select
    c.county_fips,
    c.county_name,
    c.population,
    coalesce(dc.major_declarations, 0) as major_declarations,
    coalesce(exposure.hurricanes_within_100km, 0) as hurricanes_within_100km,
    coalesce(dc.ihp_amount, 0) as ihp_amount,
    coalesce(dc.pa_federal_obligated, 0) as pa_federal_obligated,
    coalesce(nfip.flood_claims, 0) as flood_claims,
    coalesce(nfip.flood_claims_paid, 0) as flood_claims_paid,
    coalesce(dc.ihp_amount, 0) + coalesce(dc.pa_federal_obligated, 0) + coalesce(nfip.flood_claims_paid, 0) as recovery_dollars,
    coalesce(hma.mitigation_federal_obligated, 0) as mitigation_dollars,
    coalesce(hma.mitigation_projects, 0) as mitigation_projects,
    (coalesce(dc.ihp_amount, 0) + coalesce(dc.pa_federal_obligated, 0) + coalesce(nfip.flood_claims_paid, 0)) / c.population as recovery_dollars_per_resident,
    coalesce(hma.mitigation_federal_obligated, 0)
        / nullif(coalesce(dc.ihp_amount, 0) + coalesce(dc.pa_federal_obligated, 0) + coalesce(nfip.flood_claims_paid, 0), 0)
        as mitigation_per_recovery_dollar
from {{ ref('dim_county') }} c
left join dc using (county_fips)
left join hma using (county_fips)
left join nfip using (county_fips)
left join exposure using (county_fips)
