-- grain: county × year of loss
select
    county_fips || '-' || year_of_loss as county_year_key,
    county_fips,
    year_of_loss,
    count(*) as claims,
    count(*) filter (where total_paid > 0) as paid_claims,
    sum(total_paid) as total_paid,
    sum(building_damage) as building_damage,
    count(*) filter (where is_coastal_high_hazard_zone) as v_zone_claims
from {{ ref('stg_fema__nfip_claims') }}
where county_fips is not null and year_of_loss is not null
group by all
