#!/bin/bash

# Exit on error
set -e

# Default version type is "dev"
VERSION_TYPE=${1:-dev}

# Get version from package.json
VERSION=$(node -e "console.log(require('./package.json').version)")

# Strip any existing dev tags first to get the base version
BASE_VERSION=$(echo "$VERSION" | sed 's/-dev\.[0-9]\{14\}$//')

# Commit any pending changes first
if [[ -n $(git status --porcelain) ]]; then
  echo "Committing pending changes..."
  git add .
  git commit -m "Pre-release commit"
fi

# Handle version based on VERSION_TYPE
if [[ "$VERSION_TYPE" == "dev" ]]; then
  # Check if tag already exists
  if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Tag v$VERSION already exists. Using dev tag..."
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
else
  # Valid version types: patch, minor, major
  if [[ "$VERSION_TYPE" == "patch" || "$VERSION_TYPE" == "minor" || "$VERSION_TYPE" == "major" ]]; then
    echo "Bumping $VERSION_TYPE version from $BASE_VERSION..."
    
    # First set the package.json version to the base version without actually creating a tag
    # This ensures we're bumping from the base version without dev tags
    npm --no-git-tag-version version "$BASE_VERSION" >/dev/null 2>&1
    
    # Then bump the version
    npm version "$VERSION_TYPE"
    
    # Get the updated version after bump
    VERSION=$(node -e "console.log(require('./package.json').version)")
  else
    echo "Error: Invalid version type. Use 'dev', 'patch', 'minor', or 'major'."
    exit 1
  fi
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