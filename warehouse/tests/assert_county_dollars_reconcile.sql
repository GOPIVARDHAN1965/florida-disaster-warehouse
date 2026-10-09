-- county + statewide PA project dollars should add up to FEMA's own per-disaster PA total
-- (within 5%). Only disasters that publish project detail are compared: fire-management
-- grants (e.g. 2689 Suwannee Fire Complex) appear in the summary but have no project rows.
with county_rollup as (
    select disaster_number, sum(pa_federal_obligated) as county_pa
    from {{ ref('fct_disaster_county') }}
    group by disaster_number
),

statewide as (
    select disaster_number, sum(federal_share_obligated) as statewide_pa
    from {{ ref('stg_fema__pa_projects') }}
    where county_fips is null
    group by disaster_number
)

select d.disaster_number, d.declaration_title, d.pa_obligated, r.county_pa, s.statewide_pa
from {{ ref('dim_disaster') }} d
join county_rollup r using (disaster_number)
left join statewide s using (disaster_number)
where d.pa_obligated > 10e6
  and d.disaster_number in (select disaster_number from {{ ref('stg_fema__pa_projects') }})
  and abs(r.county_pa + coalesce(s.statewide_pa, 0) - d.pa_obligated) / d.pa_obligated > 0.05
