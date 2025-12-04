# Makefile for Demo 2: Smart Router (A/B Testing)
# TinyGo + proxy-wasm-go-sdk
# Self-contained with local infrastructure and scripts

.PHONY: all full build build-wasm test clean deploy deploy-skip-build destroy
.PHONY: fmt lint check tidy docker-up docker-down docker-logs setup test-live help

# Output file
WASM_FILE := smart_router.wasm

# TinyGo build flags for GCP Service Extensions sandbox
# CRITICAL flags to avoid GCP sandbox restrictions:
# - target=wasm: Pure WebAssembly, NOT wasi (blocks WASI syscalls → "restricted_callback")
# - scheduler=none: Disable goroutine scheduler (proxy-wasm requirement)
# - panic=trap: Trap on panic instead of Go runtime (avoids gojs.* imports → "missing import")
# - no-debug: Reduce binary size
TINYGO_FLAGS := -scheduler=none -target=wasm -panic=trap -no-debug

# GCP Configuration
PROJECT_ID := $(shell gcloud config get-value project 2>/dev/null)
REGION := us-central1
ARTIFACT_REPO := demo2-smart-router

# Use rustup's cargo if available (needed for wasm32 target)
REPO_ROOT := $(shell cd ../.. && pwd)

# Default target
all: build test deploy test-live

## all: Complete workflow - build, test, deploy, and verify (default target)

## quick: Build and test only (no deployment)
quick: build test

# =============================================================================
# Build Targets
# =============================================================================

## build: Build Wasm + backend + OCI image via Cloud Build
build:
	@echo "Building via Cloud Build (Wasm + backend + OCI image)..."
	gcloud builds submit $(REPO_ROOT) \
		--config=cloudbuild.yaml \
		--project=$(PROJECT_ID) \
		--substitutions=_REGION=$(REGION),_ARTIFACT_REPO=$(ARTIFACT_REPO)
	@echo "Build complete. Images pushed to $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(ARTIFACT_REPO)/"

## build-wasm: Build the Wasm binary locally with TinyGo (for development)
build-wasm:
	@echo "Building Smart Router Wasm plugin locally..."
	tinygo build -o $(WASM_FILE) $(TINYGO_FLAGS) ./main.go
	@echo "Built: $(WASM_FILE)"
	@ls -lh $(WASM_FILE)

# =============================================================================
# Test Targets
# =============================================================================

## test: Run unit tests
test:
	@echo "Running tests..."
	go test -v ./...

## test-cover: Run tests with coverage
test-cover:
	@echo "Running tests with coverage..."
	go test -v -cover ./...

## test-integration: Run integration tests with Docker
test-integration:
	@./scripts/test.sh --integration

## test-all: Run all tests
test-all:
	@./scripts/test.sh --all

# =============================================================================
# Code Quality Targets
# =============================================================================

## lint: Run golangci-lint
lint:
	@echo "Running linter..."
	golangci-lint run ./...

## fmt: Format code
fmt:
	@echo "Formatting code..."
	gofmt -w .

## fmt-check: Check code formatting
fmt-check:
	@echo "Checking code formatting..."
	@test -z "$$(gofmt -l .)" || (echo "Files need formatting:" && gofmt -l . && exit 1)

## vet: Run go vet
vet:
	@echo "Running go vet..."
	go vet ./...

## check: Run all checks (fmt, vet, lint, test)
check: fmt-check vet lint test

## tidy: Tidy go modules
tidy:
	@echo "Tidying go modules..."
	go mod tidy

# =============================================================================
# Docker Targets
# =============================================================================

## docker-up: Start local development environment
docker-up: build
	@echo "Starting local development environment..."
	docker compose -f infrastructure/docker/docker-compose.yaml up -d
	@echo ""
	@echo "Services started:"
	@echo "  - Envoy (with Wasm): http://localhost:10000"
	@echo "  - Backend: http://localhost:8080"
	@echo "  - Envoy Admin: http://localhost:9901"
	@echo ""
	@echo "Test with:"
	@echo "  curl http://localhost:10000/api/version"
	@echo "  curl -H 'Cookie: beta-tester=true' -H 'User-Agent: iPhone' -H 'X-Geo-Country: DE' http://localhost:10000/api/version"

## docker-down: Stop local development environment
docker-down:
	@echo "Stopping local development environment..."
	docker compose -f infrastructure/docker/docker-compose.yaml down

## docker-logs: View logs from all containers
docker-logs:
	docker compose -f infrastructure/docker/docker-compose.yaml logs -f

## docker-clean: Stop and remove all containers, volumes, and images
docker-clean:
	@echo "Cleaning Docker resources..."
	docker compose -f infrastructure/docker/docker-compose.yaml down -v --rmi local 2>/dev/null || true

# =============================================================================
# Deploy Targets
# =============================================================================

## deploy: Deploy to Cloud Run (uses pre-built images from make build)
deploy:
	@./scripts/deploy.sh --skip-build

## deploy-full: Build and deploy in one step
deploy-full:
	@./scripts/deploy.sh

## destroy: Destroy all Demo 2 GCP infrastructure
destroy:
	@./scripts/99-remove.sh --force

## test-live: Test deployed service via Load Balancer (with WASM filter)
test-live:
	@echo "Testing deployed service..."
	@echo ""
	@echo "=========================================="
	@echo "LOAD BALANCER with WASM Smart Router"
	@echo "=========================================="
	@LB_IP=$$(gcloud compute addresses describe demo2-smart-router-lb-ip \
		--global --format='value(address)' 2>/dev/null || echo ""); \
	if [ -n "$$LB_IP" ]; then \
		echo "Load Balancer IP: $$LB_IP"; \
		echo ""; \
		echo "1. Health check:"; \
		curl -s -k "https://$$LB_IP/health" 2>/dev/null | jq . || echo "  (LB health check failed - is WASM plugin deployed?)"; \
		echo ""; \
		echo "2. Version endpoint (standard user -> v1):"; \
		LB_TIME=$$(curl -s -k -o /tmp/lb_response.txt -w "%{time_total}" -D /tmp/lb_headers.txt "https://$$LB_IP/api/version" 2>/dev/null); \
		cat /tmp/lb_response.txt | jq . 2>/dev/null || cat /tmp/lb_response.txt; \
		echo ""; \
		echo "   ⏱️  Latency: $${LB_TIME}s"; \
		echo ""; \
		echo "3. Version endpoint (beta user -> v2):"; \
		LB_BETA_TIME=$$(curl -s -k -o /tmp/lb_beta_response.txt -w "%{time_total}" \
			-H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" \
			-H "X-Geo-Country: DE" \
			-H "Cookie: beta-tester=true" \
			-D /tmp/lb_beta_headers.txt "https://$$LB_IP/api/version" 2>/dev/null); \
		cat /tmp/lb_beta_response.txt | jq . 2>/dev/null || cat /tmp/lb_beta_response.txt; \
		echo ""; \
		echo "   ⏱️  Latency: $${LB_BETA_TIME}s"; \
		echo ""; \
		echo "4. Response headers (WASM routing):"; \
		grep -iE "x-route|x-smart" /tmp/lb_beta_headers.txt 2>/dev/null || echo "   (No routing headers found - check WASM plugin logs)"; \
		echo ""; \
		echo "Note: Direct Cloud Run access is blocked (internal-and-cloud-load-balancing ingress)."; \
		echo "All traffic must go through the Load Balancer."; \
	else \
		echo "Load Balancer not found."; \
		echo ""; \
		echo "Run 'make deploy' to deploy the full stack."; \
	fi

# =============================================================================
# Setup Targets
# =============================================================================

## setup: Set up development environment
setup:
	@./scripts/setup-dev.sh

## setup-verify: Verify development environment
setup-verify:
	@./scripts/setup-dev.sh --verify

# =============================================================================
# Utility Targets
# =============================================================================

## clean: Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -f $(WASM_FILE)
	go clean -cache
	docker compose -f infrastructure/docker/docker-compose.yaml down -v --rmi local 2>/dev/null || true
	@echo "Clean complete"

## size: Show Wasm file size
size: build
	@echo "Wasm file size:"
	@ls -lh $(WASM_FILE)

## deps: Download dependencies
deps:
	@echo "Downloading dependencies..."
	go mod download

# =============================================================================
# Help
# =============================================================================

## help: Show this help
help:
	@echo "Demo 2: Smart Router (A/B Testing)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'