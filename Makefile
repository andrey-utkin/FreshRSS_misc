ENGINE ?= podman
COMPOSE ?= podman-compose
IMAGE_NAME=decentim-freshrss
IMAGE_TAG ?= $(shell date --utc +%Y.%m.%d)
SERVER_SSH_URI ?= root@z620

CONTAINER_NAME ?= freshrss-maintenance
CONTAINER_MOUNTPOINT ?= /usr/local/src/FreshRSS

.PHONY: composer-lock
composer-lock:
	${ENGINE} build --tag freshrss-dev-base:latest -f Containerfile.dev-base .
	${ENGINE} run --name ${CONTAINER_NAME} --rm -it -v ${PWD}/../FreshRSS:${CONTAINER_MOUNTPOINT} --workdir ${CONTAINER_MOUNTPOINT} freshrss-dev-base:latest composer require stripe/stripe-php


.PHONY: image
image:
	${ENGINE} build --no-cache --tag ${IMAGE_NAME}:${IMAGE_TAG} .
	#${ENGINE} build --tag ${IMAGE_NAME}:${IMAGE_TAG} .

IMAGE_TESTS_CONTAINER_NAME ?= freshrss-image-tests
image-tests-passing:
	${ENGINE} run --name ${IMAGE_TESTS_CONTAINER_NAME} --detach --rm -it ${IMAGE_NAME}:${IMAGE_TAG}
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} composer run-script php-lint
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} composer run-script phtml-lint
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'composer install --prefer-dist --no-progress'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'composer run-script phpunit -- --no-progress'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm ci'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm run --silent markdownlint'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm run --silent stylelint'

image-tests-fixme:
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'composer run-script translations && git diff --exit-code'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'composer run-script phpcs'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'composer run-script phpstan -- --no-progress'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm run --silent eslint'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm run --silent rtlcss && git diff --exit-code'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'npm run --silent svgo && git diff --exit-code'

image-tests-whoknows:
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'mkdir -p /usr/local/bin/ && apt update && apt install -y golang'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'GOBIN=/usr/local/bin/ go install mvdan.cc/sh/v3/cmd/shfmt@v3.8.0'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c './tests/shellchecks.sh'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'curl -sL -o ./bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-linux-x86_64" && echo "c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507  ./bin/hadolint" | sha256sum -c - && chmod 700 ./bin/hadolint'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'find . -name 'Dockerfile*' -print0 | xargs -0 -n1 ./bin/hadolint --failure-threshold warning'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c "cd /usr/local/bin ; wget -q 'https://github.com/crate-ci/typos/releases/download/v1.49.0/typos-v1.49.0-x86_64-unknown-linux-musl.tar.gz' && echo '48bd2d58e02ce713b8c0f1aa239e68ee4f7d8c551013135806e6aed3938d9e10  typos-v1.49.0-x86_64-unknown-linux-musl.tar.gz' | sha256sum -c - && tar -xvf *.tar.gz './typos' && chmod +x typos && rm *.tar.gz ; cd .."
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c 'typos'
	${ENGINE} exec ${IMAGE_TESTS_CONTAINER_NAME} bash -c ':'

image-save:
	${ENGINE} image save ${IMAGE_NAME}:${IMAGE_TAG} | zstd -T0 --ultra -20 > ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst
	ln -svnf ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst container-image-latest.tar.zst

image-load:
	zstdcat container-image-latest.tar.zst | ${ENGINE} image load

.PHONY: upstream-container-shell
upstream-container-shell:
	${ENGINE} pull docker.io/freshrss/freshrss:edge
	${ENGINE} run --name ${CONTAINER_NAME} --rm -it -v ${PWD}/../FreshRSS:${CONTAINER_MOUNTPOINT} --workdir ${CONTAINER_MOUNTPOINT} docker.io/freshrss/freshrss:edge bash -l

.PHONY: dev-base-shell
dev-base-shell:
	${ENGINE} build --tag freshrss-dev-base:latest -f Containerfile.dev-base .
	${ENGINE} run --name ${CONTAINER_NAME} --rm -it -v ${PWD}/../FreshRSS:${CONTAINER_MOUNTPOINT} --workdir ${CONTAINER_MOUNTPOINT} freshrss-dev-base:latest bash -l

stop-snapshot-start:
	${COMPOSE} down
	./zfs-snapshot
	${COMPOSE} up -d

.PHONY: run-compose
run-compose:
	${COMPOSE} up -d

.PHONY: deploy-image
deploy-image:
	${MAKE} image
	${MAKE} image-save
	rsync -av --info=progress2 \
		${IMAGE_NAME}__${IMAGE_TAG}.tar.zst \
		container-image-latest.tar.zst \
		${SERVER_SSH_URI}:/var/www/news.decent.im/FreshRSS_misc
	echo "cd /var/www/news.decent.im/FreshRSS_misc && zstdcat container-image-latest.tar.zst | ${ENGINE} image load" | ssh ${SERVER_SSH_URI} bash -x -euo pipefail
