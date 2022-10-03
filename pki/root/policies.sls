{% from "../map.jinja" import salt_pki -%}
{% set tplroot = tpldir.split('/')[:-1] | join('/') -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_key = root_ca_dir ~ '/' ~ salt_pki.root_ca.key -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}
{% set root_ca_copypath = root_ca_dir ~ '/' ~ salt_pki.root_ca.copypath -%}

{# If this minion is supposed to be Root CA according to data from pillars - run states #}
{% if grains.id == salt_pki.root_ca.ca_server -%}
include:
  - ..common
  - ..hooks
  - .ca

pki_root_policies_ca_issued_cers_dir:
  file.directory:
    - name: "{{ root_ca_copypath }}"
    - mode: "0640"

pki_root_policies:
  file.managed:
    - name: /etc/salt/minion.d/signing_policies_root.conf
    - source: salt://{{ tplroot }}/signing_policies/root.jinja
    - template: jinja
    - context:
        tplroot: {{ tplroot }}
        root_ca_key: {{ root_ca_key }}
        root_ca_cert: {{ root_ca_cert }}
        root_signing_policies: {{ salt_pki.root_ca.signing_policies|json }}
        copypath: {{ root_ca_copypath }}
    # restart the salt_minion when the file is changed
    - watch_in:
      - cmd: pki_hooks_restart_salt_minion

{# Otherwise fail without changes #}
{% else -%}
pki_root_policies_fail:
  test.configurable_test_state:
    - name: "Wrong minion for Root CA role"
    - result: False
    - changes: False
    - comment: "According to pillar data this minion is not supposed to be Root CA"
{% endif -%}
