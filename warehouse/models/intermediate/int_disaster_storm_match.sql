-- link FEMA disasters to NOAA storms: a word in the declaration title equals the name of a
-- storm that was active within 7 days of the incident period. Handles multi-storm titles
-- like 'HURRICANES FRANCES AND JEANNE'.
with disasters as (
    select distinct disaster_number, declaration_title, incident_type, incident_begin_date, incident_end_date
    from {{ ref('stg_fema__disaster_declarations') }}
    where incident_type in ('Hurricane', 'Tropical Storm', 'Coastal Storm', 'Severe Storm', 'Flood')
),

title_words as (
    select d.*, unnest(regexp_extract_all(upper(declaration_title), '[A-Z]{3,}')) as word
    from disasters d
)

select distinct
    w.disaster_number,
    s.storm_id,
    s.storm_name
from title_words w
join {{ ref('int_storms') }} s
    on s.storm_name = w.word
    and s.first_observed_at::date <= w.incident_end_date + interval 7 day
    and s.last_observed_at::date >= w.incident_begin_date - interval 7 day
