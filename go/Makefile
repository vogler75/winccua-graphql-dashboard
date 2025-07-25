.PHONY: build test clean examples run-basic run-monitor run-subscriptions

# Build all examples
build:
	go build -o bin/basic_usage ./cmd/examples/basic_usage.go
	go build -o bin/monitor ./cmd/examples/monitor.go
	go build -o bin/subscriptions ./cmd/examples/subscriptions.go

# Run tests
test:
	go test ./test/... -v

# Clean build artifacts
clean:
	rm -rf bin/

# Build examples directory
examples: build

# Run individual examples
run-basic: build
	./bin/basic_usage

run-monitor: build
	./bin/monitor

run-subscriptions: build
	./bin/subscriptions

# Download dependencies
mod:
	go mod download
	go mod tidy

# Format code
fmt:
	go fmt ./...

# Vet code
vet:
	go vet ./...

# Run all checks
check: fmt vet test

# Install locally
install:
	go install ./cmd/examples/...