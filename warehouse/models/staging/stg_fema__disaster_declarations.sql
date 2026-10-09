-- latest version of each declaration row (raw is append-only across incremental loads)
with latest as (
    select * from {{ source('openfema', 'disaster_declarations') }}
    qualify row_number() over (partition by id order by lastRefresh desc) = 1
)

select
    id as declaration_id,
    femaDeclarationString as declaration_string,
    disasterNumber::int as disaster_number,
    declarationType as declaration_type,
    {{ to_date('declarationDate') }} as declaration_date,
    incidentType as incident_type,
    declarationTitle as declaration_title,
    {{ to_date('incidentBeginDate') }} as incident_begin_date,
    {{ to_date('incidentEndDate') }} as incident_end_date,
    {{ to_date('disasterCloseoutDate') }} as closeout_date,
    ihProgramDeclared::boolean as ih_declared,
    iaProgramDeclared::boolean as ia_declared,
    paProgramDeclared::boolean as pa_declared,
    hmProgramDeclared::boolean as hm_declared,
    tribalRequest::boolean as is_tribal_request,
    designatedArea as designated_area,
    fipsCountyCode = '000' as is_statewide,
    -- tribal designations reuse county FIPS of the reservation; keep only true county designations
    case when designatedArea ilike '%(County)%' then {{ fl_county_fips('fipsCountyCode') }} end as county_fips,
    lastRefresh::timestamp as last_refresh
from latest
