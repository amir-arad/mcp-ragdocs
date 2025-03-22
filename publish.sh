#!/bin/bash

# Exit on error
set -e

# Get version from package.json
VERSION=$(node -e "console.log(require('./package.json').version)")

# Commit changes if there are any
echo "Checking for uncommitted changes..."
if [[ -n $(git status --porcelain) ]]; then
  echo "Committing changes..."
  git add .
  git commit -m "Release v$VERSION"
else
  echo "No changes to commit."
fi

# Create a git tag for this version
echo "Creating git tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"

# Push changes and tags to GitHub
echo "Pushing changes and tags to GitHub..."
git push origin main
git push origin "v$VERSION"

# Build the Docker image
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

# Tag as latest
echo "Tagging as latest..."
docker tag amirarad/mcp-ragdocs:$VERSION amirarad/mcp-ragdocs:latest

# Login to Docker Hub (will prompt for credentials if not already logged in)
echo "Logging in to Docker Hub..."
docker login

# Push the versioned image
echo "Pushing amirarad/mcp-ragdocs:$VERSION..."
docker push amirarad/mcp-ragdocs:$VERSION

# Push the latest tag
echo "Pushing amirarad/mcp-ragdocs:latest..."
docker push amirarad/mcp-ragdocs:latest

# Create a GitHub release using the GitHub CLI if available
if command -v gh &> /dev/null; then
  echo "Creating GitHub release..."
  gh release create "v$VERSION" \
    --title "v$VERSION" \
    --notes "Release v$VERSION of MCP RAG Documentation Server with HTTP/SSE transport" \
    --target main
else
  echo "GitHub CLI not found. Please create a release manually at:"
  echo "https://github.com/amir-arad/mcp-ragdocs/releases/new?tag=v$VERSION"
fi

echo "Successfully published amirarad/mcp-ragdocs:$VERSION and amirarad/mcp-ragdocs:latest"
echo "Release v$VERSION created on GitHub"