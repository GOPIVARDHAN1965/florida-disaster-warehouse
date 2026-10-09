{# generic test: column has no negative values (nulls allowed) #}
{% test non_negative(model, column_name) %}
select * from {{ model }} where {{ column_name }} < 0
{% endtest %}
