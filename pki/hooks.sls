restart_salt_minion:
  cmd.wait:
    - name: 'salt-call --local service.restart salt-minion --out-file /dev/null'
    - bg: true
