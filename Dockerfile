# Usage: podman build --tag decentim-freshrss:2024.11.15 .

FROM docker.io/freshrss/freshrss:1.24.3

ENV TZ UTC
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
	apt-get install --no-install-recommends -y \
	curl ffmpeg php time w3m && \
	curl -sS https://getcomposer.org/installer -o composer-setup.php && \
	php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
	rm -rf /var/lib/apt/lists/*
