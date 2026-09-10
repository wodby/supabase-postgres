REPO = wodby/supabase-postgres
TAG ?= 17
PLATFORM ?= linux/arm64

.PHONY: build buildx-build test push
build:
	docker build -t $(REPO):$(TAG) .

buildx-build:
	docker buildx build --platform $(PLATFORM) --load -t $(REPO):$(TAG) .

test:
	IMAGE=$(REPO):$(TAG) bash tests/supabase.sh

push:
	docker push $(REPO):$(TAG)
