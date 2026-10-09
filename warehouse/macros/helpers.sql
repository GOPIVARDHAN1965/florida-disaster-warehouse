{# use the configured schema name as-is (staging / intermediate / marts), not <target>_<schema> #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name if custom_schema_name else target.schema }}
{%- endmacro %}

{# great-circle distance in km between two lat/lon points #}
{% macro haversine_km(lat1, lon1, lat2, lon2) -%}
    2 * 6371 * asin(sqrt(
        pow(sin(radians({{ lat2 }} - {{ lat1 }}) / 2), 2)
        + cos(radians({{ lat1 }})) * cos(radians({{ lat2 }})) * pow(sin(radians({{ lon2 }} - {{ lon1 }}) / 2), 2)
    ))
{%- endmacro %}

{# join key for county names spelled differently across sources:
   'Miami-Dade (County)', 'MIAMI-DADE', 'Miami-Dade County', 'St. Johns', 'De Soto' -> 'MIAMIDADE', 'STJOHNS', 'DESOTO' #}
{% macro county_key(name) -%}
    regexp_replace(upper(regexp_replace({{ name }}, '\s*\(?County\)?\s*$', '', 'i')), '[^A-Z]', '', 'g')
{%- endmacro %}

{# 3-digit county code -> Florida 5-digit FIPS. '000' means statewide (null);
   12025 is Dade County's pre-1997 code, renamed Miami-Dade = 12086 #}
{% macro fl_county_fips(code) -%}
    case
        when {{ code }} is null or lpad({{ code }}, 3, '0') = '000' then null
        when lpad({{ code }}, 3, '0') = '025' then '12086'
        else '12' || lpad({{ code }}, 3, '0')
    end
{%- endmacro %}

{# OpenFEMA stores dates as ISO strings ('2024-08-10T00:00:00.000Z') #}
{% macro to_date(col) -%}
    try_cast(left({{ col }}, 10) as date)
{%- endmacro %}
