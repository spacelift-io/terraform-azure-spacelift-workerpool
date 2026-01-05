.PHONY: build clean deploy test

BINARY_NAME=autoscaler
BUILD_DIR=.

# Build for Linux (Azure Functions runtime)
build:
	@echo "Building autoscaler for Linux..."
	GOOS=linux GOARCH=amd64 go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/autoscaler
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Build for local testing
build-local:
	@echo "Building autoscaler for local platform..."
	go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/autoscaler
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BUILD_DIR)/$(BINARY_NAME)
	rm -f deploy.zip
	@echo "Clean complete"

# Create deployment package
package: build
	@echo "Creating deployment package..."
	zip -r deploy.zip $(BINARY_NAME) host.json api/
	@echo "Package created: deploy.zip"

# Run tests
test:
	@echo "Running tests..."
	go test -v ./...

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod tidy

# Run locally for testing
run-local: build-local
	@echo "Starting autoscaler locally..."
	./$(BINARY_NAME)
