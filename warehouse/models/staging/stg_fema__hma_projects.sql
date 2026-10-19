-- HmaSubapplications v2 (replaced HMA Projects v4 in Oct 2026); one row per subapplication.
-- County comes as a name list ('Lee', 'FLAGLER COUNTY; VOLUSIA COUNTY', 'Statewide'); the first
-- listed county is the project's county, resolved to FIPS in fct_hma_projects
select
    id as hma_project_id,
    subapplicationIdentifier as project_identifier,
    program as program_area,  -- HMGP, FMA, BRIC, PDM, ...
    fiscalYear::int as program_fy,
    try_cast(disasterNumber as int) as disaster_number,
    {{ county_key("split_part(benefitingCounties, ';', 1)") }} as county_key,
    benefitingCounties as project_counties,
    primaryActivity as project_type,
    status,
    subapplicantName as subrecipient,
    {{ to_date('dateSubmittedToFema') }} as date_submitted,
    totalSubapplicationAmount::double as project_amount,
    totalObligatedAmount::double as federal_share_obligated,
    federalSharePercentage::double as cost_share_pct,
    benefitCostRatio::double as benefit_cost_ratio
from {{ source('openfema', 'hma_projects') }}
