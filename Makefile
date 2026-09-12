ENGINE ?= podman
COMPOSE ?= podman-compose
IMAGE_NAME=decentim-freshrss
IMAGE_TAG ?= $(shell date --utc +%Y.%m.%d)
SERVER_SSH_URI ?= root@z620

.PHONY: image
image:
	#${ENGINE} build --no-cache --tag ${IMAGE_NAME}:${IMAGE_TAG} .
	${ENGINE} build --tag ${IMAGE_NAME}:${IMAGE_TAG} .
	${ENGINE} image save ${IMAGE_NAME}:${IMAGE_TAG} | zstd -T0 --ultra -20 > ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst
	ln -svnf ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst container-image-latest.tar.zst

.PHONY: upstream-container-shell
upstream-container-shell:
	${ENGINE} run --rm -it -v ${PWD}/../FreshRSS:/usr/local/src/FreshRSS docker.io/freshrss/freshrss:1.30.0 bash -l

stop-snapshot-start:
	${COMPOSE} down
	./zfs-snapshot
	${COMPOSE} up -d

.PHONY: run-compose
run-compose:
	${COMPOSE} up -d

.PHONY: deploy-image
deploy-image:
	rsync -av --info=progress2 \
		${IMAGE_NAME}__${IMAGE_TAG}.tar.zst \
		container-image-latest.tar.zst \
		${SERVER_SSH_URI}:/var/www/news.decent.im/FreshRSS_misc
	echo "cd /var/www/news.decent.im/FreshRSS_misc && zstdcat container-image-latest.tar.zst | ${ENGINE} image load" | ssh ${SERVER_SSH_URI} bash -x -euo pipefail
