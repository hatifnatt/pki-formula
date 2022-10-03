{% from "../map.jinja" import salt_pki -%}
{% from "../macros.jinja" import format_kwargs -%}

{% set rootca = salt_pki.root_ca -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_key = root_ca_dir ~ '/' ~ salt_pki.root_ca.key -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}

{# If this minion is supposed to be Root CA according to data from pillars - run states #}
{% if grains.id == salt_pki.root_ca.ca_server -%}
include:
  - ..common

pki_root_ca_dir:
  file.directory:
    - name: "{{ root_ca_dir }}"
    - mode: "0600"
    - require:
      - file: pki_common_dir

pki_root_ca_key:
  x509.private_key_managed:
    - name: "{{ root_ca_key }}"
    - bits: 4096
    - backup: True
    - mode: "0600"
    - require:
      - file: pki_root_ca_dir

pki_root_ca_cert:
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
      - x509: pki_root_ca_key

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
pki_root_ca_cert_publish:
  module.run:
  # Workaround for deprecated `module.run` syntax, subject to change in Salt 3005
  {%- if 'module.run' in salt['config.get']('use_superseded', [])
      or grains['saltversioninfo'] >= [3005] %}
    ### new style ###
    - mine.send:
      {%- if grains['saltversioninfo'] < [3000] %}
      - func: pki_root_ca
      {%- else %}
      - name: pki_root_ca
      {%- endif %}
      - mine_function: x509.get_pem_entry
      - text: "{{ root_ca_cert }}"
    - onchanges:
      - x509: pki_root_ca_cert
  {%- else %}
    ### legacy style ###
    - name: mine.send
    {%- if grains['saltversioninfo'] < [3000] %}
    - func: pki_root_ca
    {%- else %}
    - m_name: pki_root_ca
    {%- endif %}
    - kwargs:
        mine_function: x509.get_pem_entry
        text: "{{ root_ca_cert }}"
    - onchanges:
      - x509: pki_root_ca_cert
  {%- endif %}

{# Otherwise fail without changes #}
{% else -%}
pki_root_ca_fail:
  test.configurable_test_state:
    - name: "Wrong minion for Root CA role"
    - result: False
    - changes: False
    - comment: "According to pillar data this minion is not supposed to be Root CA"
{% endif -%}
