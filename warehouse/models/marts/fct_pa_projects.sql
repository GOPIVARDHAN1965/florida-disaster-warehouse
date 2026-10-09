select
    p.*,
    d.declaration_year,
    d.storm_name,
    p.first_obligation_date - p.declaration_date as days_to_first_obligation
from {{ ref('stg_fema__pa_projects') }} p
left join {{ ref('dim_disaster') }} d using (disaster_number)
