DBT = cd warehouse && DBT_PROFILES_DIR=. uv run dbt

.PHONY: all extract transform model export docs clean

all: extract transform model export docs

extract:            ## pull OpenFEMA (incremental), NOAA HURDAT2, Census into data/raw
	uv run python extract/openfema.py
	uv run python extract/reference.py

transform:          ## build + test every dbt model
	$(DBT) build

model:              ## train / evaluate, write predictions back to the warehouse
	uv run python model/train.py

export:             ## marts -> docs/data.json for the dashboard
	uv run python export/site_data.py

docs:               ## dbt docs (lineage graph) as one static page under docs/dbt/
	$(DBT) docs generate --static
	mkdir -p docs/dbt && cp warehouse/target/static_index.html docs/dbt/index.html

clean:
	rm -f data/warehouse.duckdb && $(DBT) clean
