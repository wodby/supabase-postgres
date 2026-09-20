-include env_make

# Accept legacy build arguments during the image revision transition.
IMAGE_REVISION ?= $(STABILITY_TAG)

REPO = wodby/supabase-postgres
POSTGRES_VER ?= 17.6
POSTGRES_MAJOR_VER = $(word 1,$(subst ., ,$(POSTGRES_VER)))
TAG ?= $(POSTGRES_MAJOR_VER)
PLATFORM ?= linux/arm64

ifneq ($(IMAGE_REVISION),)
    override TAG := $(TAG)-$(IMAGE_REVISION)
endif
IMAGETOOLS_TAG ?= $(TAG)
ifneq ($(ARCH),)
    override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-imagetools-create test push check-version
build: check-version
	docker build -t $(REPO):$(TAG) .

buildx-build: check-version
	docker buildx build --platform $(PLATFORM) --load -t $(REPO):$(TAG) .

# The PostgreSQL tag must describe the bundle actually pinned by the Dockerfile.
check-version:
	@grep -Fq 'ARG SUPABASE_IMAGE=supabase/postgres:$(POSTGRES_VER).' Dockerfile

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
		$(REPO):$(TAG)-amd64 $(REPO):$(TAG)-arm64

test:
	IMAGE=$(REPO):$(TAG) bash tests/supabase.sh

push:
	docker push $(REPO):$(TAG)

# Keep CI scans aligned with the version, variant and architecture built by make.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
