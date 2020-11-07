{% from "./map.jinja" import salt_pki -%}

# Install packages required for salt x509 module to function
crypto_pkgs:
  pkg.installed:
    - names: {{ salt_pki.crypto_pkgs|tojson }}
    - reload_modules: True

# Base directory for all certificates created with this formula
pki_dir:
  file.directory:
    - name: "{{ salt_pki.base_dir }}"
    - mode: "0644"
