-- Individuals & Households Program, homeowners, by disaster × county × city × zip
select
    id as row_id,
    disasterNumber::int as disaster_number,
    county as county_name_raw,
    {{ county_key('county') }} as county_key,
    city,
    zipCode as zip_code,
    validRegistrations::int as valid_registrations,
    totalInspected::int as total_inspected,
    totalDamage::double as fema_inspected_damage,
    approvedForFemaAssistance::int as approved_registrations,
    totalApprovedIhpAmount::double as ihp_approved_amount,
    repairReplaceAmount::double as repair_replace_amount,
    rentalAmount::double as rental_amount,
    otherNeedsAmount::double as other_needs_amount,
    totalMaxGrants::int as max_grants
from {{ source('openfema', 'housing_assistance_owners') }}
