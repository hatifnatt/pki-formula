{% from "./map.jinja" import salt_pki -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}


print_dict:
  test.configurable_test_state:
    - name: Print some dict
    - result: True
    - changes: False
    - comment: |
        {{ salt_pki|yaml(False)|indent(width=8) }}
