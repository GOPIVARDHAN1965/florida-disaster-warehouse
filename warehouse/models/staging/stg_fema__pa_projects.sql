-- Public Assistance project worksheets; the API row hash changes with every update,
-- so the business key is disaster × applicant × project worksheet number
with latest as (
    select * from {{ source('openfema', 'pa_projects') }}
    qualify row_number() over (
        partition by disasterNumber, applicantId, pwNumber order by lastRefresh desc
    ) = 1
)

select
    disasterNumber || '-' || applicantId || '-' || pwNumber as pa_project_key,
    disasterNumber::int as disaster_number,
    {{ to_date('declarationDate') }} as declaration_date,
    incidentType as incident_type,
    pwNumber::int as pw_number,
    applicantId as applicant_id,
    applicationTitle as application_title,
    damageCategoryCode as damage_category_code,
    damageCategoryDescrip as damage_category,
    damageCategoryCode in ('A', 'B') as is_emergency_work,
    projectStatus as project_status,
    projectProcessStep as process_step,
    projectSize as project_size,
    county as county_name_raw,
    case when county not ilike 'statewide%' then {{ fl_county_fips('countyCode') }} end as county_fips,
    projectAmount::double as project_amount,
    federalShareObligated::double as federal_share_obligated,
    totalObligated::double as total_obligated,
    mitigationAmount::double as mitigation_amount,
    {{ to_date('firstObligationDate') }} as first_obligation_date,
    {{ to_date('lastObligationDate') }} as last_obligation_date,
    lastRefresh::timestamp as last_refresh
from latest
