-- Individual Assistance rows whose county name doesn't map to a Florida county.
-- Tribal reservations are expected (they aren't counties); anything else means a new spelling.
select distinct county_name_raw
from {{ ref('stg_fema__housing_assistance_owners') }}
where county_key not in (select county_key from {{ ref('int_counties') }})
  and county_name_raw not ilike '%reservation%'
  and county_name_raw not ilike '%tribe%'
  and county_name_raw <> 'Sorrento Shores'  -- census-designated place reported in place of Lake County
