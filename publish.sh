#!/bin/bash

# Exit on error
set -e

# Get version from package.json
VERSION=$(node -e "console.log(require('./package.json').version)")

# Commit any pending changes first
if [[ -n $(git status --porcelain) ]]; then
  echo "Committing pending changes..."
  git add .
  git commit -m "Pre-release commit"
fi

# Check if tag already exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists. Using dev tag..."
  # Strip any existing dev tags first
  BASE_VERSION=$(echo "$VERSION" | sed 's/-dev\.[0-9]\{14\}$//')
  DEV_VERSION="${BASE_VERSION}-dev.$(date +%Y%m%d%H%M%S)"
  echo "Using version: $DEV_VERSION"
  
  # Update package.json with the dev version and create git tag
  npm version "$DEV_VERSION"
  
  # Get the updated version
  VERSION="$DEV_VERSION"
else
  # Use npm version to update version and create git tag
  echo "Creating release v$VERSION..."
  npm version "$VERSION" --allow-same-version
fi

# Push changes and tags to GitHub
echo "Pushing changes and tags to GitHub..."
git push origin main
git push origin "v$VERSION"

# Login to Docker Hub (will prompt for credentials if not already logged in)
echo "Logging in to Docker Hub..."
docker login

# Build the main application Docker image
echo "Building Docker image amirarad/mcp-ragdocs:$VERSION..."
# Add labels for GitHub repository linking
docker build \
  --label "org.opencontainers.image.source=https://github.com/amir-arad/mcp-ragdocs" \
  --label "org.opencontainers.image.url=https://github.com/amir-arad/mcp-ragdocs" \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  --label "org.opencontainers.image.version=$VERSION" \
  --label "org.opencontainers.image.title=MCP RAG Documentation Server" \
  --label "org.opencontainers.image.description=A containerized MCP server implementation providing tools for retrieving and processing documentation through vector search" \
  -t amirarad/mcp-ragdocs:$VERSION .

# Tag main application as latest
echo "Tagging main application as latest..."
docker tag amirarad/mcp-ragdocs:$VERSION amirarad/mcp-ragdocs:latest

# Build the custom Ollama Docker image
echo "Building Docker image amirarad/mcp-ragdocs-ollama:$VERSION..."
# Add labels for GitHub repository linking
docker build \
  --label "org.opencontainers.image.source=https://github.com/amir-arad/mcp-ragdocs" \
  --label "org.opencontainers.image.url=https://github.com/amir-arad/mcp-ragdocs" \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  --label "org.opencontainers.image.version=$VERSION" \
  --label "org.opencontainers.image.title=MCP RAG Documentation Server Ollama" \
  --label "org.opencontainers.image.description=Custom Ollama image with pre-installed nomic-embed-text model for MCP RAG Documentation Server" \
  -t amirarad/mcp-ragdocs-ollama:$VERSION \
  -f Dockerfile.ollama .

# Tag Ollama image as latest
echo "Tagging Ollama image as latest..."
docker tag amirarad/mcp-ragdocs-ollama:$VERSION amirarad/mcp-ragdocs-ollama:latest

# Push the versioned images
echo "Pushing amirarad/mcp-ragdocs:$VERSION..."
docker push amirarad/mcp-ragdocs:$VERSION
echo "Pushing amirarad/mcp-ragdocs-ollama:$VERSION..."
docker push amirarad/mcp-ragdocs-ollama:$VERSION

# Push the latest tags
echo "Pushing amirarad/mcp-ragdocs:latest..."
docker push amirarad/mcp-ragdocs:latest
echo "Pushing amirarad/mcp-ragdocs-ollama:latest..."
docker push amirarad/mcp-ragdocs-ollama:latest

# Create a GitHub release using the GitHub CLI if available
if command -v gh &> /dev/null; then
  echo "Creating GitHub release..."
  # Explicitly specify the repository
  gh release create "v$VERSION" \
    --repo "amir-arad/mcp-ragdocs" \
    --title "v$VERSION" \
    --notes "Release v$VERSION of MCP RAG Documentation Server with HTTP/SSE transport" \
    --target main
else
  echo "GitHub CLI not found. Please create a release manually at:"
  echo "https://github.com/amir-arad/mcp-ragdocs/releases/new?tag=v$VERSION"
fi

echo "Successfully published amirarad/mcp-ragdocs:$VERSION, amirarad/mcp-ragdocs:latest, amirarad/mcp-ragdocs-ollama:$VERSION, and amirarad/mcp-ragdocs-ollama:latest"