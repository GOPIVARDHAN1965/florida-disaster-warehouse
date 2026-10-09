select
    h.*,
    d.storm_name as triggering_storm  -- HMGP is funded off a disaster declaration; FMA/BRIC/PDM are not
from {{ ref('stg_fema__hma_projects') }} h
left join {{ ref('dim_disaster') }} d using (disaster_number)
