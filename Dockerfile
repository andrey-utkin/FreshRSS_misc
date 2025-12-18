# Usage: podman build --tag decentim-freshrss:2025.12.17 .

#FROM docker.io/freshrss/freshrss:edge
FROM docker.io/freshrss/freshrss:1.27.1

ENV TZ UTC

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        curl \
        ffmpeg \
        git \
        npm \
        php \
        python3-pip \
        rsync \
        shellcheck \
        shfmt \
        sudo \
        time \
        w3m \
    ;
RUN rm -rf /var/lib/apt/lists/*

RUN curl -sS https://getcomposer.org/installer -o composer-setup.php && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer

RUN pip3 install --break-system-packages piper-tts

# Download the voice used.
# Placement follows the example of ArchLinux AUR piper-voices-common package.
RUN mkdir -p /usr/share/piper-voices/en/en_US/lessac/high/ \
    && python3 -m piper.download_voices en_US-lessac-high --data-dir /usr/share/piper-voices/en/en_US/lessac/high/

# Support the way Extension-TTS as of before 2025-12-17 invokes piper
RUN mkdir -p /usr/share/piper \
    && ln -sv /usr/local/bin/piper /usr/share/piper/piper

# Support the way Extension-TTS as of before 2025-12-17 refers to model path
RUN ln -sv /usr/share/piper-voices /piper-voices

# for prod:
# checks out default branch
RUN cd /usr/local/src && git clone https://github.com/decent-im/FreshRSS
# for dev:
# checks out current branch
#RUN --mount=type=bind,src=./FreshRSS,dst=/host/FreshRSS,ro  cd /usr/local/src && git clone /host/FreshRSS
# for dev - END

# any useful exclusions?
RUN rsync -av /usr/local/src/FreshRSS/ /var/www/FreshRSS
RUN cd /var/www/FreshRSS && composer install

RUN cd /usr/local/src && git clone https://github.com/decent-im/xExtension-Readable
RUN rsync -av /usr/local/src/xExtension-Readable/* /var/www/FreshRSS/extensions

RUN cd /usr/local/src && git clone https://github.com/decent-im/FreshRSS_Extensions FreshRSS_Extensions_decentim
RUN rsync -av /usr/local/src/FreshRSS_Extensions_decentim/xExtension-TTS /var/www/FreshRSS/extensions

RUN cd /usr/local/src && git clone https://github.com/FreshRSS/Extensions FreshRSS_Extensions_upstream
RUN rsync -av /usr/local/src/FreshRSS_Extensions_upstream/xExtension-ReadingTime /var/www/FreshRSS/extensions
RUN rsync -av /usr/local/src/FreshRSS_Extensions_upstream/xExtension-YouTube     /var/www/FreshRSS/extensions
# Wallabag extension dropped as not used by any current customer
