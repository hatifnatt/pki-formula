{% from "../map.jinja" import salt_pki -%}
{% from "../macros.jinja" import format_kwargs -%}

{% set rootca = salt_pki.root_ca -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_key = root_ca_dir ~ '/' ~ salt_pki.root_ca.key -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}

include:
  - ..common

root_ca_dir:
  file.directory:
    - name: "{{ root_ca_dir }}"
    - mode: "0600"
    - require:
      - file: pki_dir

root_ca_key:
  x509.private_key_managed:
    - name: "{{ root_ca_key }}"
    - bits: 4096
    - backup: True
    - mode: "0600"
    - require:
      - file: root_ca_dir

root_ca_cert:
  x509.certificate_managed:
    - name: "{{ root_ca_cert }}"
    - signing_private_key: "{{ root_ca_key }}"
    {{- format_kwargs(rootca.kwargs) }}
    - basicConstraints: "critical CA:true"
    - keyUsage: "critical digitalSignature, cRLSign, keyCertSign"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 7300 # 20 years
    # days_remaining is set to 0 to disable automatic renewal by the x509 module.
    # We don’t want the root certificate to be automatically recreated, invalidating all of our existing certificates.
    - days_remaining: 0
    - backup: True
    - require:
      - x509: root_ca_key

root_ca_cert_publish:
  # This is deprecated `module.run` syntax, to be changed in Salt Sodium.
  # https://docs.saltstack.com/en/latest/topics/mine/#mine-functions
  module.run:
    - name: mine.send
    # create alias which represent combination of function and data
    # without alias when same fuction executed twice on same minion, only last dataset wil be available
    - func: pki_root_ca
    - kwargs:
        mine_function: x509.get_pem_entry
        text: "{{ root_ca_cert }}"
    - onchanges:
      - x509: root_ca_cert
