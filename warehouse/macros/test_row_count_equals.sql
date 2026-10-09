{% test row_count_equals(model, expected) %}
select count(*) as n from {{ model }} having count(*) <> {{ expected }}
{% endtest %}
