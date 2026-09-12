IMAGE_NAME=decentim-freshrss
IMAGE_TAG ?= $(shell date --utc +%Y.%m.%d)
SERVER_SSH_URI ?= root@z620
.PHONY: image
image:
	#podman build --no-cache --tag ${IMAGE_NAME}:${IMAGE_TAG} .
	podman build --tag ${IMAGE_NAME}:${IMAGE_TAG} .
	podman image save ${IMAGE_NAME}:${IMAGE_TAG} | zstd -T0 --ultra -20 > ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst
	ln -svnf ${IMAGE_NAME}__${IMAGE_TAG}.tar.zst container-image-latest.tar.zst

.PHONY: upstream-container-shell
upstream-container-shell:
	podman run --rm -it -v ${PWD}/../FreshRSS:/usr/local/src/FreshRSS docker.io/freshrss/freshrss:1.30.0 bash -l

.PHONY: run-compose
run-compose:
	podman-compose up -d

.PHONY: deploy-image
deploy-image:
	rsync -av --info=progress2 \
		${IMAGE_NAME}__${IMAGE_TAG}.tar.zst \
		container-image-latest.tar.zst \
		${SERVER_SSH_URI}:/var/www/news.decent.im/FreshRSS_misc
	echo "cd /var/www/news.decent.im/FreshRSS_misc && zstdcat container-image-latest.tar.zst | podman image load" | ssh ${SERVER_SSH_URI} bash -x -euo pipefail
