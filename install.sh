#!/bin/sh
set -e

# check if the current user is root
if [ "$(id -u)" != "0" ]; then
    echo "Error: you must be root to execute this script" >&2
    exit 1
fi

# check if is Mac OS
if [ "$(uname)" = "Darwin" ]; then
    echo "Error: MacOS is not supported" >&2
    exit 1
fi

# check if is running inside a container
if [ -f /.dockerenv ]; then
    echo "Error: running inside a container is not supported" >&2
    exit 1
fi

# check if something is running on port 80
if lsof -i :80 -sTCP:LISTEN >/dev/null; then
    echo "Error: something is already running on port 80" >&2
    exit 1
fi

# check if something is running on port 443
if lsof -i :443 -sTCP:LISTEN >/dev/null; then
    echo "Error: something is already running on port 443" >&2
    exit 1
fi

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

if command_exists docker; then
  echo "Docker already installed"
else
  # curl -sSL https://get.docker.com | sh
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

docker swarm leave --force 1> /dev/null 2> /dev/null || true

docker pull easypanel/easypanel:latest

docker run --rm -i \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup
