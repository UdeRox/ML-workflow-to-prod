.DEFAULT_GOAL := help

IMAGE_NAME ?= bank-marketing-api
IMAGE_TAG ?= local
CONTAINER_NAME ?= bank-marketing-api-local
HOST_PORT ?= 8001

.PHONY: help serve test lint repro dvc-auth docker-build docker-run docker-check docker-logs docker-stop

help:
	@printf '%s\n' \
		'Local development:' \
		'  make serve          Run the API directly with hot reload' \
		'  make test           Run the unit and API tests' \
		'  make lint           Run the configured Ruff checks' \
		'  make repro          Reproduce the DVC pipeline' \
		'' \
		'Local Docker:' \
		'  make docker-build   Build the API image (requires models/model.cbm)' \
		'  make docker-run     Start the container on http://localhost:$(HOST_PORT)' \
		'  make docker-check   Check /health and /docs in the running container' \
		'  make docker-logs    Follow the container logs (Ctrl-C to stop following)' \
		'  make docker-stop    Stop and remove the local container' \
		'' \
		'Override defaults, e.g. make docker-run HOST_PORT=9000'

serve:
	uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

test:
	uv run pytest -q

lint:
	uv run ruff check --select E4,E7,E9,F,E402 app src tests monitoring

repro:
	uv run dvc repro

dvc-auth:
	@test -n "$$DAGSHUB_OWNER" || (echo "DAGSHUB_OWNER is required" >&2; exit 1)
	@test -n "$$DAGSHUB_TOKEN" || (echo "DAGSHUB_TOKEN is required" >&2; exit 1)
	uv run dvc remote modify --local origin user "$$DAGSHUB_OWNER"
	uv run dvc remote modify --local origin password "$$DAGSHUB_TOKEN"

docker-build:
	@test -f models/model.cbm || (echo "models/model.cbm is missing; pull it with DVC first" >&2; exit 1)
	docker build \
		--build-arg MODEL_VERSION="$(IMAGE_TAG)" \
		--tag "$(IMAGE_NAME):$(IMAGE_TAG)" .

docker-run:
	docker run --detach \
		--name "$(CONTAINER_NAME)" \
		--publish "127.0.0.1:$(HOST_PORT):8000" \
		"$(IMAGE_NAME):$(IMAGE_TAG)"
	@printf 'Container started. Open http://localhost:%s/docs\n' "$(HOST_PORT)"

docker-check:
	@for attempt in $$(seq 1 30); do \
		if curl --fail --silent "http://127.0.0.1:$(HOST_PORT)/health"; then \
			printf '\n'; \
			curl --fail --silent --show-error --output /dev/null \
				--write-out 'Docs HTTP %{http_code}\n' \
				"http://127.0.0.1:$(HOST_PORT)/docs"; \
			exit 0; \
		fi; \
		sleep 2; \
	done; \
	echo "Container did not become healthy; recent logs:" >&2; \
	docker logs "$(CONTAINER_NAME)"; \
	exit 1

docker-logs:
	docker logs --follow "$(CONTAINER_NAME)"

docker-stop:
	docker rm --force "$(CONTAINER_NAME)"
