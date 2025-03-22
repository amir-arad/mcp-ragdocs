#!/bin/bash
echo "==== Container Diagnostics ===="
echo "Testing connection to Qdrant at $QDRANT_URL..."
curl -v $QDRANT_URL

echo -e "\nTesting connection to Ollama..."
echo "OLLAMA_BASE_URL=$OLLAMA_BASE_URL"
curl -v $OLLAMA_BASE_URL/api/embeddings -H "Content-Type: application/json" -d '{"model":"nomic-embed-text", "prompt":"test"}'

# Check if the curl command response contains the "model not found" error
if curl -s $OLLAMA_BASE_URL/api/embeddings -H "Content-Type: application/json" -d '{"model":"nomic-embed-text", "prompt":"test"}' | grep -q "model.*not found"; then
  echo -e "\nThe model nomic-embed-text was not found. Attempting to pull it now..."
  # Pull the model
  curl -X POST $OLLAMA_BASE_URL/api/pull -H "Content-Type: application/json" -d '{"name":"nomic-embed-text"}'
  echo -e "\nWaiting for model to finish downloading (this may take a few minutes)..."
  # Check if the model is now available
  curl -v $OLLAMA_BASE_URL/api/embeddings -H "Content-Type: application/json" -d '{"model":"nomic-embed-text", "prompt":"test"}'
fi

echo -e "\nChecking DNS resolution of host.docker.internal..."
if command -v ping &> /dev/null; then
  ping -c 2 host.docker.internal
else
  echo "Ping command not available, trying nslookup instead"
  getent hosts host.docker.internal || echo "getent failed, host.docker.internal may not be properly configured"
fi

# echo -e "\nChecking if Web server port is available..."
# nc -z localhost 3030 && echo "Port 3030 is available" || echo "Port 3030 is not available"

# echo -e "\nChecking if MCP server port is available..."
# nc -z localhost 3031 && echo "Port 3031 is available" || echo "Port 3031 is not available"