{% from "./map.jinja" import salt_pki -%}
{% from "./macros.jinja" import format_kwargs -%}

# This state will simply issue certificates based on pillar data and save them into PKI directory
# with secure permissions, this certificates can be used later in some service formula.
# I.e. you can copy it to another location, set user and group relevant for a service.

include:
  - .common
{% for name, data in salt_pki.issue|dictsort -%}
  {%- if 'include' in data %}
  - {{ data.include }}
  {%- endif %}
{% endfor %}

{% for name, data in salt_pki.issue|dictsort -%}
pki_issue_<{{ name }}>_key:
  x509.private_key_managed:
    {{- format_kwargs(data.key) }}
    {# Usage of prereq cause a problem - state won't be executed if reuqired state won't generate changes
    in current case if certificate does not need update. So if keyfiles properties need to be changed i.e.
    user, group, mode etc. this state still won't be executed.
    Disable prereq for now.
    {%- if salt['file.file_exists'](data.key.name) %}
    - prereq:
      - x509: {{ name }}_cert
    {%- endif %} #}
    {%- if 'include' in data %}
    - require_in:
      - sls: {{ data.include }}
    {%- endif %}

pki_issue_<{{ name }}>_cert:
  x509.certificate_managed:
    {{- format_kwargs(data.cert) }}
    {%- if 'include' in data %}
    - require_in:
      - sls: {{ data.include }}
    {%- endif %}

{% if 'service' in data -%}
pki_issue_<{{ data | traverse('service:name', name) }}>_service:
  service.running:
    - name: {{ data | traverse('service:name', name) }}
    - reload: {{ data | traverse('service:reload', False) }}
    - watch:
      - x509: pki_issue_<{{ name }}>_key
      - x509: pki_issue_<{{ name }}>_cert
{% endif -%}
{% endfor %}
