select
    id as claim_id,
    countyCode as county_fips,
    {{ to_date('dateOfLoss') }} as date_of_loss,
    yearOfLoss::int as year_of_loss,
    floodEvent as flood_event,
    eventDesignationNumber as event_designation_number,
    causeOfDamage as cause_of_damage,
    ratedFloodZone as rated_flood_zone,
    left(ratedFloodZone, 1) = 'V' as is_coastal_high_hazard_zone,
    occupancyType::int as occupancy_type,
    primaryResidenceIndicator::boolean as is_primary_residence,
    elevatedBuildingIndicator::boolean as is_elevated_building,
    buildingDamageAmount::double as building_damage,
    contentsDamageAmount::double as contents_damage,
    coalesce(netBuildingPaymentAmount::double, 0)
        + coalesce(netContentsPaymentAmount::double, 0)
        + coalesce(netIccPaymentAmount::double, 0) as total_paid,
    totalBuildingInsuranceCoverage::double as building_coverage,
    latitude::double as lat,
    longitude::double as lon
from {{ source('openfema', 'nfip_claims') }}
