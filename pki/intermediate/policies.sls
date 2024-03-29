{% from "../map.jinja" import salt_pki -%}
{% set tplroot = tpldir.split('/')[:-1] | join('/') -%}

include:
  - ..common
  - ..hooks
  - .ca

{% for interca in salt_pki.intermediate_ca -%}
{% set intermediate_ca_dir = salt_pki.base_dir ~'/' ~ interca.dir -%}
{% set intermediate_ca_key = intermediate_ca_dir ~ '/' ~ interca.key -%}
{% set intermediate_ca_cert = intermediate_ca_dir ~ '/' ~ interca.cert -%}
{% set intermediate_ca_copypath = intermediate_ca_dir ~ '/' ~ interca.copypath -%}

{# If this minion is supposed to be Intermediate CA according to data from pillars - run states #}
{% if grains.id == interca.ca_server -%}

pki_intermediate_policies_<{{ interca.name }}>_issued_cers_dir:
  file.directory:
    - name: "{{ intermediate_ca_copypath }}"
    - mode: "0644"

pki_intermediate_policies_<{{ interca.name }}>:
  file.managed:
    - name: /etc/salt/minion.d/signing_policies_{{ interca.name }}.conf
    - source: salt://{{ tplroot }}/signing_policies/{{ interca.name }}.jinja
    - template: jinja
    - context:
        tplroot: {{ tplroot }}
        intermediate_ca_key: {{ intermediate_ca_key }}
        intermediate_ca_cert: {{ intermediate_ca_cert }}
        intermediate_signing_policies: {{ interca.signing_policies|json }}
        copypath: {{ intermediate_ca_copypath }}
    # restart the salt_minion when the file changes
    - watch_in:
      - cmd: pki_hooks_restart_salt_minion

{# Otherwise proceed without changes #}
{% else -%}
pki_intermediate_policies_<{{ interca.name }}>_skip:
  test.configurable_test_state:
    - name: "Wrong minion for '{{ interca.name }}' Intermediate CA role"
    - result: True
    - changes: False
    - comment: |
        According to pillar data this minion is not supposed to be '{{ interca.name }}' Intermediate CA,
        skipping signing policy installation
{% endif -%}

{% endfor %}
