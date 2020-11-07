{% from "../map.jinja" import salt_pki -%}
{% from "../macros.jinja" import format_kwargs -%}
include:
  - ..common
  - ..hooks

{% for interca in salt_pki.intermediate_ca -%}
{% set intermediate_ca_dir = salt_pki.base_dir ~'/' ~ interca.dir -%}
{% set intermediate_ca_key = intermediate_ca_dir ~ '/' ~ interca.key -%}
{% set intermediate_ca_cert = intermediate_ca_dir ~ '/' ~ interca.cert -%}

{{ interca.name }}_dir:
  file.directory:
    - name: "{{ intermediate_ca_dir }}"
    - mode: "0600"
    - require:
      - file: pki_dir

{{ interca.name }}_key:
  x509.private_key_managed:
    - name: "{{ intermediate_ca_key }}"
    - bits: 4096
    - backup: True
    - mode: "0600"
    - require:
      - file: intermediate_ca_dir

{{ interca.name }}_cert:
  x509.certificate_managed:
    - name: "{{ intermediate_ca_cert }}"
    - public_key: "{{ intermediate_ca_key }}"
    - ca_server: {{ salt_pki.root_ca.server | default(grains.id) }}
    - signing_policy: intermediate
    - backup: True
    {{- format_kwargs(interca.kwargs) }}
    - require:
      - x509: intermediate_ca_key

{{ interca.name }}_cert_publish:
  # This is deprecated `module.run` syntax, to be changed in Salt Sodium.
  # https://docs.saltstack.com/en/latest/topics/mine/#mine-functions
  module.run:
    - name: mine.send
    # create alias which represent combination of function and data
    # without alias when same fuction executed twice on same minion, only last dataset wil be available
    - func: pki_{{ interca.name }}
    - kwargs:
        mine_function: x509.get_pem_entry
        text: "{{ intermediate_ca_cert }}"
    - onchanges:
      - x509: {{ interca.name }}_cert
{% endfor %}
