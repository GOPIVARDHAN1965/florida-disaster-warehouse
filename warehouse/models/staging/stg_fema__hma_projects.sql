select
    id as hma_project_id,
    projectIdentifier as project_identifier,
    programArea as program_area,  -- HMGP, FMA, BRIC, PDM, ...
    programFy::int as program_fy,
    disasterNumber::int as disaster_number,
    {{ fl_county_fips('countyCode') }} as county_fips,  -- null = statewide project
    county as county_name_raw,
    projectCounties as project_counties,
    projectType as project_type,
    status,
    subrecipient,
    {{ to_date('dateApproved') }} as date_approved,
    {{ to_date('dateClosed') }} as date_closed,
    projectAmount::double as project_amount,
    federalShareObligated::double as federal_share_obligated,
    costSharePercentage::double as cost_share_pct,
    benefitCostRatio::double as benefit_cost_ratio,
    netValueBenefits::double as net_value_benefits,
    numberOfProperties::int as number_of_properties,
    numberOfFinalProperties::int as number_of_final_properties
from {{ source('openfema', 'hma_projects') }}
