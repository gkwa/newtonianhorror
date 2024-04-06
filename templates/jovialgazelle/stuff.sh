#!/usr/bin/env bash

cat >{{ .Container }}.yml <<'EOF'
#cloud-config
package_update: true
package_reboot_if_required: true

packages:
- unzip
- curl

write_files:

- content: |
    #!/usr/bin/env bash

    set -e
    set -u

    cd /tmp

    curl -Lo ringgem.zip https://github.com/taylormonacelli/ringgem/archive/refs/heads/master.zip
    unzip ringgem.zip

    # FIXME:
    export HOME=/root

    ls /tmp/ringgem-master >/dev/null

  path: /root/install_nix.sh
  append: true
  permissions: "0755"


- content: |
    #!/usr/bin/env bash

    set -e
    set -u

    curl -Lo ringgem.zip https://github.com/taylormonacelli/ringgem/archive/refs/heads/master.zip
    unzip ringgem.zip

  path: /root/install_ringgem.sh
  append: true
  permissions: "0755"

- content: |
    #!/usr/bin/env bash

    set -e
    set -u

    if ! command task --version &>/dev/null; then
        cd /usr/local
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
        /usr/local/bin/task --version
    fi

  path: /root/install_task.sh
  append: true
  permissions: "0755"

runcmd:
- /root/install_task.sh
- /root/install_ringgem.sh
EOF

incus ls --format=json | jq 'map(select(.name == "{{ .Container }}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}
incus launch images:ubuntu/22.04/cloud {{ .Container }} --config=user.user-data="$(cat {{ .Container }}.yml)"
incus exec {{ .Container }} -- cloud-init status --wait
incus ls {{ .Container }}