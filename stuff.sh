#!/usr/bin/env bash

cat >{{ container }}.yml <<'EOF'
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

    task --dir=ringgem-master install-nix-on-linux

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
#- /root/install_nix.sh
EOF

incus ls --format=json | jq 'map(select(.name == "{{ container }}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}
incus launch images:ubuntu/22.04/cloud {{ container }} --config=user.user-data="$(cat {{ container }}.yml)"
incus exec {{ container }} -- cloud-init status --wait
incus exec {{ container }} -- shutdown now

# create nix image
timeout 30s bash -c 'until incus publish {{ container }} --alias nix-jammy; do sleep 1s; done'

incus ls --format=json | jq 'map(select(.name == "{{ container }}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}

# ensure nix-jammy image exists now:
incus image list --format=json | jq -e 'map(select(.aliases[].name == "nix-jammy")) | length > 0' >/dev/null

# launch new image from image we just created
incus launch nix-jammy {{ container }}
incus exec {{ container }} -- bash -c 'time nix --extra-experimental-features "nix-command flakes" search nixpkgs firefox'
