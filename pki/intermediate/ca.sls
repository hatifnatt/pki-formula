{% from "../map.jinja" import salt_pki -%}
{% from "../macros.jinja" import format_kwargs -%}

include:
  - ..common
  - ..hooks

{% for interca in salt_pki.intermediate_ca -%}
{% set intermediate_ca_dir = salt_pki.base_dir ~'/' ~ interca.dir -%}
{% set intermediate_ca_key = intermediate_ca_dir ~ '/' ~ interca.key -%}
{% set intermediate_ca_cert = intermediate_ca_dir ~ '/' ~ interca.cert -%}

{# If this minion is supposed to be Intermediate CA according to data from pillars - run states #}
{% if grains.id == interca.ca_server -%}

pki_intermediate_ca_<{{ interca.name }}>_dir:
  file.directory:
    - name: "{{ intermediate_ca_dir }}"
    - mode: "0600"
    - require:
      - file: pki_common_dir

pki_intermediate_ca_<{{ interca.name }}>_key:
  x509.private_key_managed:
    - name: "{{ intermediate_ca_key }}"
    - bits: 4096
    - backup: True
    - mode: "0600"
    - require:
      - file: pki_intermediate_ca_<{{ interca.name }}>_dir

pki_intermediate_ca_<{{ interca.name }}>_cert:
  x509.certificate_managed:
    - name: "{{ intermediate_ca_cert }}"
    - private_key: "{{ intermediate_ca_key }}"
    - ca_server: {{ salt_pki.root_ca.ca_server | default(grains.id) }}
    - signing_policy: intermediate
    - backup: True
    {{- format_kwargs(interca.kwargs) }}
    - require:
      - x509: pki_intermediate_ca_<{{ interca.name }}>_key

{# Jinja hell below caused by two reasons:
   - changes of module.run call style https://docs.saltstack.com/en/latest/ref/states/all/salt.states.module.html
     therefor compatibility workaround is required
   - mine fuctions was rewritten without any notice in docs or in changelog
     https://github.com/saltstack/salt/commit/da29e1501e1182000272a0c5cff1597cf70fcbe1#diff-a64f3cb030f6172ac00301df45b9a678e36cbb2cac6d16c62e31cd8adfb1334cL187-R204
     func` argument was replaced with `name`, therefor this compatibility workaround is required
     https://github.com/saltstack/salt/issues/56584#issuecomment-621230980
#}

{# Here we'll create 'named mine function' - alias which represent combination of function and data
without alias when same fuction executed twice on same minion, only last dataset will be available
https://docs.saltstack.com/en/latest/topics/mine/#mine-functions #}
pki_intermediate_ca_<{{ interca.name }}>_cert_publish:
  module.run:
  {%- if 'module.run' in salt['config.get']('use_superseded', [])
      or grains['saltversioninfo'] >= [3005] %}
    ### new style ###
    - mine.send:
      {%- if grains['saltversioninfo'] < [3000] %}
      - func: pki_{{ interca.name }}
      {%- else %}
      - name: pki_{{ interca.name }}
      {%- endif %}
      - mine_function: x509.get_pem_entry
      - text: "{{ intermediate_ca_cert }}"
    - onchanges:
      - x509: pki_intermediate_ca_<{{ interca.name }}>_cert
  {%- else %}
    ### legacy style ###
    - name: mine.send
    {%- if grains['saltversioninfo'] < [3000] %}
    - func: pki_{{ interca.name }}
    {%- else %}
    - m_name: pki_{{ interca.name }}
    {%- endif %}
    - kwargs:
        mine_function: x509.get_pem_entry
        text: "{{ intermediate_ca_cert }}"
    - onchanges:
      - x509: pki_intermediate_ca_<{{ interca.name }}>_cert
  {%- endif %}

{# Otherwise proceed without changes #}
{% else -%}
pki_intermediate_ca_<{{ interca.name }}>_skip:
  test.configurable_test_state:
    - name: "Wrong minion for '{{ interca.name }}' Intermediate CA role"
    - result: True
    - changes: False
    - comment: |
        According to pillar data this minion is not supposed to be '{{ interca.name }}' Intermediate CA,
        skipping cerificate issue
{% endif -%}

{% endfor %}
