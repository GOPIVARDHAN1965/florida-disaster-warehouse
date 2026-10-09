-- one row per Florida federal disaster / emergency declaration
with declarations as (
    select
        disaster_number,
        any_value(declaration_string) as declaration_string,
        any_value(declaration_type) as declaration_type,
        any_value(declaration_title) as declaration_title,
        any_value(incident_type) as incident_type,
        min(declaration_date) as declaration_date,
        min(incident_begin_date) as incident_begin_date,
        max(incident_end_date) as incident_end_date,
        max(closeout_date) as closeout_date,
        count(distinct county_fips) as counties_designated,
        bool_or(ia_declared or ih_declared) as any_individual_assistance,
        bool_or(pa_declared) as any_public_assistance,
        bool_or(hm_declared) as any_hazard_mitigation
    from {{ ref('stg_fema__disaster_declarations') }}
    group by disaster_number
),

storm as (
    -- a few declarations cover two storms; keep the stronger one as the primary link
    select m.disaster_number, m.storm_id, s.storm_name, s.peak_category
    from {{ ref('int_disaster_storm_match') }} m
    join {{ ref('int_storms') }} s using (storm_id)
    qualify row_number() over (partition by m.disaster_number order by s.peak_wind_kt desc) = 1
)

select
    d.*,
    year(d.declaration_date) as declaration_year,
    storm.storm_id,
    storm.storm_name,
    storm.peak_category as storm_peak_category,
    s.ihp_amount,
    s.pa_obligated,
    s.pa_emergency_work_obligated,
    s.pa_permanent_work_obligated,
    s.hmgp_obligated
from declarations d
left join storm using (disaster_number)
left join {{ ref('stg_fema__disaster_summaries') }} s using (disaster_number)
