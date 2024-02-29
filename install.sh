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
if lsof -i :80 >/dev/null; then
    echo "Error: something is already running on port 80" >&2
    exit 1
fi

# check if something is running on port 443
if lsof -i :443 >/dev/null; then
    echo "Error: something is already running on port 443" >&2
    exit 1
fi

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

if command_exists docker; then
  echo "Docker already installed"
else
  curl -sSL https://get.docker.com | sh
fi

docker swarm leave --force 1> /dev/null 2> /dev/null || true

docker pull easypanel/easypanel:latest

docker run --rm -i \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup
