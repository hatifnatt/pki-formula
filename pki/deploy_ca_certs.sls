{% from "./map.jinja" import salt_pki -%}
{% set root_ca_dir = salt_pki.base_dir ~'/' ~ salt_pki.root_ca.dir -%}
{% set root_ca_cert = root_ca_dir ~ '/' ~ salt_pki.root_ca.cert -%}

include:
  - .common

# Add CA certificates from files
ca_certs_dir:
  file.directory:
    - name: {{ salt_pki.ca_certs.dir }}
    - makedirs: true

{% for cert in salt_pki.ca_certs.certs -%}
{% set name_no_ext = cert.name.split('.')[0:-1] | join('.') -%}
{% set ensure = cert.get('ensure', 'present' ) -%}
{% if ensure == 'present' -%}
{{ name_no_ext }}_present:
  file.managed:
    - name: /usr/local/share/ca-certificates/{{ cert.name }}
    - source: salt://{{ tpldir }}/ca_certs/{{ cert.name }}
    - watch_in:
      - cmd: add_ca_certs

{% elif ensure == 'absent' -%}
{{ name_no_ext }}_absent:
  file.absent:
    - name: /usr/local/share/ca-certificates/{{ cert.name }}
    - watch_in:
      - cmd: rebuild_ca_certs
{% endif -%}
{% endfor %}

# Add CA certs issued by this formula
# If this minion is CA itself deploy certificate directly from file
{% if grains.id == salt_pki.root_ca.server -%}
deploy_root_ca_from_file:
  x509.pem_managed:
    - name: "{{ salt_pki.ca_certs.dir }}/salt_root_ca.crt"
    - text: "{{ root_ca_cert }}"
    - watch_in:
      - cmd: rebuild_ca_certs

# Otherwise deploy certificate from Salt Mine
{% else -%}
deploy_root_ca_from_mine:
  x509.pem_managed:
    - name: "{{ salt_pki.ca_certs.dir }}/salt_root_ca.crt"
    - text: {{ salt['mine.get'](salt_pki.root_ca.server, 'pki_root_ca')[salt_pki.root_ca.server]|replace('\n', '') }}
    - watch_in:
      - cmd: rebuild_ca_certs
{% endif %}

{% for interca in salt_pki.intermediate_ca -%}
{% set intermediate_ca_dir = salt_pki.base_dir ~'/' ~ interca.dir -%}
{% set intermediate_ca_cert = intermediate_ca_dir ~ '/' ~ interca.cert -%}

{% if grains.id == interca.server -%}
deploy_{{ interca.name }}_from_file:
  x509.pem_managed:
    - name: "{{ salt_pki.ca_certs.dir }}/salt_{{ interca.name }}.crt"
    - text: "{{ intermediate_ca_cert }}"
    - watch_in:
      - cmd: rebuild_ca_certs

{% else -%}
deploy_{{ interca.name }}_from_mine:
  x509.pem_managed:
    - name: "{{ salt_pki.ca_certs.dir }}/salt_{{ interca.name }}.crt"
    - text: {{ salt['mine.get'](interca.server, 'pki_' ~ interca.name)[interca.server]|replace('\n', '') }}
    - watch_in:
      - cmd: rebuild_ca_certs
{% endif %}
{% endfor %}

# Only add new CA certs
add_ca_certs:
  cmd.wait:
    - name: {{ salt_pki.ca_certs.cmd_add }}

# Full rebuild system CA storage
# Broken symlinks will be removed
rebuild_ca_certs:
  cmd.wait:
    - name: {{ salt_pki.ca_certs.cmd_rebuild }}
