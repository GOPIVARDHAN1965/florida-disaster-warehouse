with latest as (
    select * from {{ source('openfema', 'disaster_summaries') }}
    qualify row_number() over (partition by disasterNumber order by lastRefresh desc) = 1
)

select
    disasterNumber::int as disaster_number,
    totalNumberIaApproved::int as ia_registrations_approved,
    totalAmountIhpApproved::double as ihp_amount,
    totalAmountHaApproved::double as housing_assistance_amount,
    totalAmountOnaApproved::double as other_needs_amount,
    totalObligatedAmountPa::double as pa_obligated,
    totalObligatedAmountCatAb::double as pa_emergency_work_obligated,   -- categories A-B: debris, protective measures
    totalObligatedAmountCatC2g::double as pa_permanent_work_obligated,  -- categories C-G: roads, buildings, utilities...
    totalObligatedAmountHmgp::double as hmgp_obligated,
    lastRefresh::timestamp as last_refresh
from latest
