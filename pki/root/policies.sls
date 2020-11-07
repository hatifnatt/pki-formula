{% from "../map.jinja" import salt_pki -%}
{% set tplroot = tpldir.split('/')[:-1] | join('/') -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_key = root_ca_dir ~ '/' ~ salt_pki.root_ca.key -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}
{% set root_ca_copypath = root_ca_dir ~ '/' ~ salt_pki.root_ca.copypath -%}

include:
  - ..common
  - ..hooks
  - .ca

root_ca_issued_cers_dir:
  file.directory:
    - name: "{{ root_ca_copypath }}"
    - mode: "0640"

root_signing_policies:
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
      - cmd: restart_salt_minion
