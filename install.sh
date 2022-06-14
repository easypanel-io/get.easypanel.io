#!/bin/sh
set -e

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

if command_exists docker; then
    echo "Docker already installed"
else
    curl -sSL https://get.docker.com | sh
fi

docker run --rm -i \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup
