-- grain: disaster × county. What was declared there and how much money went there.
with declared as (
    select
        disaster_number,
        county_fips,
        bool_or(ia_declared or ih_declared) as individual_assistance_declared,
        bool_or(pa_declared) as public_assistance_declared,
        bool_or(hm_declared) as hazard_mitigation_declared,
        min(declaration_date) as declaration_date
    from {{ ref('stg_fema__disaster_declarations') }}
    where county_fips is not null
    group by all
),

ihp as (
    select
        h.disaster_number,
        c.county_fips,
        sum(h.valid_registrations) as ihp_registrations,
        sum(h.approved_registrations) as ihp_approved_registrations,
        sum(h.fema_inspected_damage) as ihp_inspected_damage,
        sum(h.ihp_approved_amount) as ihp_amount
    from {{ ref('stg_fema__housing_assistance_owners') }} h
    join {{ ref('int_counties') }} c using (county_key)
    group by all
),

pa as (
    select
        disaster_number,
        county_fips,
        count(*) as pa_projects,
        sum(federal_share_obligated) as pa_federal_obligated,
        sum(federal_share_obligated) filter (where is_emergency_work) as pa_emergency_work_obligated
    from {{ ref('stg_fema__pa_projects') }}
    where county_fips is not null
    group by all
),

-- money can land in a county with no county-level declaration row (e.g. fire-management
-- declarations), so the grain is every disaster × county seen in any source
keys as (
    select * from (
        select disaster_number, county_fips from declared
        union
        select disaster_number, county_fips from ihp
        union
        select disaster_number, county_fips from pa
    )
    -- a handful of IHP/PA rows carry disaster numbers with no Florida declaration (source noise)
    where disaster_number in (select disaster_number from {{ ref('stg_fema__disaster_declarations') }})
)

select
    keys.disaster_number || '-' || keys.county_fips as disaster_county_key,
    keys.disaster_number,
    keys.county_fips,
    coalesce(declared.individual_assistance_declared, false) as individual_assistance_declared,
    coalesce(declared.public_assistance_declared, false) as public_assistance_declared,
    coalesce(declared.hazard_mitigation_declared, false) as hazard_mitigation_declared,
    declared.county_fips is not null as county_designated,
    coalesce(declared.declaration_date, d.declaration_date) as declaration_date,
    coalesce(ihp.ihp_registrations, 0) as ihp_registrations,
    coalesce(ihp.ihp_approved_registrations, 0) as ihp_approved_registrations,
    coalesce(ihp.ihp_inspected_damage, 0) as ihp_inspected_damage,
    coalesce(ihp.ihp_amount, 0) as ihp_amount,
    coalesce(pa.pa_projects, 0) as pa_projects,
    coalesce(pa.pa_federal_obligated, 0) as pa_federal_obligated,
    coalesce(pa.pa_emergency_work_obligated, 0) as pa_emergency_work_obligated
from keys
left join declared using (disaster_number, county_fips)
left join ihp using (disaster_number, county_fips)
left join pa using (disaster_number, county_fips)
left join (
    select disaster_number, min(declaration_date) as declaration_date
    from {{ ref('stg_fema__disaster_declarations') }} group by 1
) d using (disaster_number)
