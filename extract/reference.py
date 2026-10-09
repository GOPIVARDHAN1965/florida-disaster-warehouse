"""Extract reference data: NOAA HURDAT2 Atlantic storm tracks and Census county data.

Writes data/raw/noaa/hurdat2_tracks.parquet, data/raw/census/county_population.parquet
and data/raw/census/county_centroids.parquet (full refresh each run; all small).
"""
import csv
import io
import re
import urllib.request
import zipfile
from pathlib import Path

import duckdb

RAW = Path(__file__).parent.parent / "data" / "raw"
HURDAT_DIR = "https://www.nhc.noaa.gov/data/hurdat/"
# ponytail: Census vintages pinned; bump yearly when the new estimates file lands
POPEST = "https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/counties/totals/co-est2025-alldata.csv"
GAZETTEER = "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2024_Gazetteer/2024_Gaz_counties_national.zip"


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "fl-disaster-warehouse"}), timeout=120) as r:
        return r.read()


def to_parquet(rows, columns, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute(f"CREATE TABLE t ({', '.join(f'{c} VARCHAR' for c in columns)})")
    con.executemany(f"INSERT INTO t VALUES ({', '.join('?' * len(columns))})", rows)
    con.execute(f"COPY t TO '{path}' (FORMAT parquet, COMPRESSION zstd)")
    print(f"{path.relative_to(RAW)}: {len(rows):,} rows")


def hurdat2():
    """Latest Atlantic best-track file -> one row per 6-hourly track point."""
    listing = get(HURDAT_DIR).decode()

    def released(fname):  # release stamp is MMDDYY or MMDDYYYY
        s = re.search(r"-(\d+)\.txt$", fname).group(1)
        return (int(s[4:]) % 100, int(s[:2]), int(s[2:4]))

    fname = max(set(re.findall(r"hurdat2-1851-\d{4}-\d+\.txt", listing)), key=released)
    rows, storm = [], None
    for line in get(HURDAT_DIR + fname).decode().splitlines():
        f = [x.strip() for x in line.split(",")]
        if re.fullmatch(r"AL\d{6}", f[0]):
            storm = f[0], f[1]
            continue
        lat = float(f[4][:-1]) * (1 if f[4].endswith("N") else -1)
        lon = float(f[5][:-1]) * (-1 if f[5].endswith("W") else 1)
        rows.append((*storm, f[0], f[1], f[2], f[3], str(lat), str(lon), f[6], f[7]))
    print(f"hurdat2 source: {fname}")
    to_parquet(rows, ["storm_id", "storm_name", "obs_date", "obs_time", "record_id", "status",
                      "lat", "lon", "max_wind_kt", "min_pressure_mb"], RAW / "noaa" / "hurdat2_tracks.parquet")


def census():
    pop = csv.DictReader(io.StringIO(get(POPEST).decode("latin-1")))
    years = range(2020, 2026)
    rows = [(r["STATE"] + r["COUNTY"], r["CTYNAME"], str(y), r[f"POPESTIMATE{y}"])
            for r in pop if r["STATE"] == "12" and r["SUMLEV"] == "050" for y in years]
    to_parquet(rows, ["county_fips", "county_name", "year", "population"], RAW / "census" / "county_population.parquet")

    with zipfile.ZipFile(io.BytesIO(get(GAZETTEER))) as z:
        text = z.read(z.namelist()[0]).decode("utf-8")
    gaz = csv.DictReader(io.StringIO(text), delimiter="\t")
    gaz.fieldnames = [h.strip() for h in gaz.fieldnames]
    rows = [(r["GEOID"], r["NAME"], r["ALAND_SQMI"], r["AWATER_SQMI"], r["INTPTLAT"].strip(), r["INTPTLONG"].strip())
            for r in gaz if r["USPS"] == "FL"]
    to_parquet(rows, ["county_fips", "county_name", "land_sqmi", "water_sqmi", "lat", "lon"],
               RAW / "census" / "county_centroids.parquet")


if __name__ == "__main__":
    hurdat2()
    census()
