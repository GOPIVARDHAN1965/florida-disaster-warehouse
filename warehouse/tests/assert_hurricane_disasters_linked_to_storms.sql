-- every Florida major-disaster declaration for a hurricane or tropical storm since 2000
-- must be linked to a NOAA HURDAT2 storm; a miss means the title-matching logic broke
select disaster_number, declaration_title
from {{ ref('dim_disaster') }}
where declaration_type = 'DR'
  and incident_type in ('Hurricane', 'Tropical Storm')
  and declaration_year >= 2000
  and storm_id is null
