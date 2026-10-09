"""Extract Florida datasets from the OpenFEMA API into raw Parquet.

Raw layer is append-only: every run writes data/raw/openfema/<name>/<load_id>.parquet.
- incremental datasets (have `lastRefresh`): fetch only rows refreshed after the
  stored high-watermark; staging dedupes to the latest version of each key.
- full datasets (no change timestamp): each run replaces the folder with a fresh pull.

Usage: python extract/openfema.py [--full]
"""
import json
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import duckdb

API = "https://www.fema.gov/api/open"
RAW = Path(__file__).parent.parent / "data" / "raw" / "openfema"
STATE = RAW.parent / "_state.json"
PAGE = 10_000

# name: (endpoint, filter, incremental?, stable sort key, select)
DATASETS = {
    "disaster_declarations": ("v2/DisasterDeclarationsSummaries", "state eq 'FL'", True, "id", None),
    "disaster_summaries": ("v1/FemaWebDisasterSummaries", None, True, "id", None),  # national; filtered to FL in dbt
    "housing_assistance_owners": ("v2/HousingAssistanceOwners", "state eq 'FL'", False, "id", None),
    "pa_projects": ("v2/PublicAssistanceFundedProjectsDetails", "stateAbbreviation eq 'FL'", True, "hash", None),
    "hma_projects": ("v4/HazardMitigationAssistanceProjects", "state eq 'Florida'", False, "id", None),
    "nfip_claims": ("v3/NfipClaims", "state eq 'FL'", False, "id",
                    "id,countyCode,dateOfLoss,yearOfLoss,floodEvent,eventDesignationNumber,causeOfDamage,"
                    "ratedFloodZone,occupancyType,primaryResidenceIndicator,elevatedBuildingIndicator,"
                    "buildingDamageAmount,contentsDamageAmount,netBuildingPaymentAmount,"
                    "netContentsPaymentAmount,netIccPaymentAmount,totalBuildingInsuranceCoverage,"
                    "latitude,longitude"),
}


def fetch(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return json.load(r)
        except OSError as e:
            if attempt == 3:
                raise
            print(f"  retry {attempt + 1}: {e}", flush=True)
            time.sleep(10 * (attempt + 1))


def pull(endpoint, flt, order, select):
    """Yield every record matching the filter, paging by $skip over a stable sort."""
    entity = endpoint.split("/")[1]
    skip, total = 0, None
    while total is None or skip < total:
        params = {"$top": PAGE, "$skip": skip, "$inlinecount": "allpages", "$orderby": order}
        if flt:
            params["$filter"] = flt
        if select:
            params["$select"] = select
        page = fetch(f"{API}/{endpoint}?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}")
        total = page["metadata"]["count"]
        rows = page[entity]
        if not rows:
            break
        yield from rows
        skip += len(rows)
        print(f"  {min(skip, total):,}/{total:,}", flush=True)


def write_parquet(rows, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".ndjson", delete=False) as f:
        for r in rows:
            # every value as text: raw stays a faithful copy, typing happens in dbt staging
            f.write(json.dumps({k: v if v is None or isinstance(v, str) else json.dumps(v) for k, v in r.items()}) + "\n")
    duckdb.sql(f"""COPY (SELECT COLUMNS(*)::VARCHAR FROM read_json('{f.name}', format='newline_delimited'))
                   TO '{path}' (FORMAT parquet, COMPRESSION zstd)""")
    Path(f.name).unlink()


def main(full=False):
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    load_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for name, (endpoint, flt, incremental, order, select) in DATASETS.items():
        mark = state.get(name) if incremental and not full else None
        query = flt
        if mark:
            query = f"({flt}) and lastRefresh gt '{mark}'" if flt else f"lastRefresh gt '{mark}'"
        print(f"{name}: {'incremental since ' + mark if mark else 'full'}", flush=True)
        rows = list(pull(endpoint, query, order, select))
        folder = RAW / name
        if not mark:  # a full pull replaces whatever was there
            for old in folder.glob("*.parquet"):
                old.unlink()
        if rows:
            write_parquet(rows, folder / f"{load_id}.parquet")
            if incremental:
                state[name] = max(r["lastRefresh"] for r in rows)
        print(f"  -> {len(rows):,} rows", flush=True)
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(state, indent=2))


if __name__ == "__main__":
    main(full="--full" in sys.argv)
