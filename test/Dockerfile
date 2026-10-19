FROM ubuntu:24.04
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bats shellcheck sudo >/dev/null \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m tester \
 && mkdir -p /srv/root-env
USER tester
WORKDIR /w
