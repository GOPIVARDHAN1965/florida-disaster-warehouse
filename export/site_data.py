"""Export warehouse marts + model metrics + dbt test results to docs/data.json for the dashboard."""
import json
from datetime import datetime, timezone
from pathlib import Path

import duckdb

ROOT = Path(__file__).parent.parent
con = duckdb.connect(str(ROOT / "data" / "warehouse.duckdb"), read_only=True)


def rows(sql):
    rel = con.sql(sql)
    return [dict(zip(rel.columns, r)) for r in rel.fetchall()]


def run_results():
    path = ROOT / "warehouse" / "target" / "run_results.json"
    if not path.exists():
        return None
    res = json.loads(path.read_text())["results"]
    tests = [r for r in res if r["unique_id"].startswith("test.")]
    return {"models": sum(r["unique_id"].startswith("model.") for r in res),
            "tests": len(tests),
            "tests_passed": sum(r["status"] == "pass" for r in tests),
            "tests_warned": sum(r["status"] == "warn" for r in tests),
            "tests_failed": sum(r["status"] in ("fail", "error") for r in tests)}


data = {
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    "sources": rows("""
        select 'OpenFEMA disaster declarations' as source, count(*) as rows from staging.stg_fema__disaster_declarations
        union all select 'OpenFEMA Individual Assistance (owners)', count(*) from staging.stg_fema__housing_assistance_owners
        union all select 'OpenFEMA Public Assistance projects', count(*) from staging.stg_fema__pa_projects
        union all select 'OpenFEMA Hazard Mitigation projects', count(*) from staging.stg_fema__hma_projects
        union all select 'OpenFEMA NFIP flood claims', count(*) from staging.stg_fema__nfip_claims
        union all select 'NOAA HURDAT2 track points', count(*) from staging.stg_noaa__track_points
        union all select 'Census counties', count(*) from marts.dim_county"""),
    "dbt": run_results(),
    "counties": rows("""
        select county_fips as fips, county_name as name, population, major_declarations, hurricanes_within_100km,
               round(ihp_amount) as ihp, round(pa_federal_obligated) as pa, flood_claims, round(flood_claims_paid) as nfip,
               round(recovery_dollars) as recovery, round(mitigation_dollars) as mitigation,
               round(recovery_dollars_per_resident) as recovery_per_resident,
               round(mitigation_per_recovery_dollar, 4) as mitigation_ratio
        from marts.mart_county_summary order by county_fips"""),
    "storms": rows("""
        select disaster_number, declaration_year as year, storm_name as storm, storm_peak_category as category,
               counties_designated, round(ihp_amount) as ihp, round(pa_obligated) as pa, round(hmgp_obligated) as hmgp,
               (select round(median(days_to_first_obligation)) from marts.fct_pa_projects p
                 where p.disaster_number = d.disaster_number) as median_days_to_pa
        from marts.dim_disaster d
        where declaration_type = 'DR' and storm_id is not null and declaration_year >= 2000
          and counties_designated > 0
        order by declaration_date desc"""),
    "model": json.loads((ROOT / "model" / "metrics.json").read_text()),
    # out-of-fold predictions for 2004+ hurricanes/TS that led to a declaration, for the map
    "predictions": rows("""
        select f.storm_name as storm, f.season, f.county_fips as fips, f.ia_declared as actual,
               round(p.p_ia_logistic, 3) as p
        from marts.ml_storm_county_features f
        join marts.ml_predictions p using (storm_county_key)
        where f.storm_id in (select storm_id from marts.dim_disaster where storm_id is not null and any_individual_assistance)
        order by f.season desc, f.storm_name"""),
}

out = ROOT / "docs" / "data.json"
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(data, separators=(",", ":"), default=str))
print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size / 1024:.0f} KB)")
