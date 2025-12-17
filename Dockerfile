# Usage: podman build --tag decentim-freshrss:2025.12.17 .

# also :edge is worth trying
FROM docker.io/freshrss/freshrss:1.27.1

ENV TZ UTC

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
	apt-get install --no-install-recommends -y \
	git npm  shfmt shellcheck  sudo \
	curl ffmpeg php time w3m && \
	curl -sS https://getcomposer.org/installer -o composer-setup.php && \
	php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
	rm -rf /var/lib/apt/lists/*
