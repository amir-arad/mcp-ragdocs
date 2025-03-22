# Use Playwright's pre-built image with browsers already installed
FROM mcr.microsoft.com/playwright:v1.40.0-focal

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .
RUN npm run build
RUN mkdir -p /app/build/public
RUN cp -r /app/src/public/* /app/build/public/

# Install only essential utilities needed for diagnostics
# curl - for API testing and model pulling
# iputils-ping - for network diagnostics
# dnsutils - for DNS resolution checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl iputils-ping dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Add metadata labels
LABEL org.opencontainers.image.title="MCP RAG Documentation Server"
LABEL org.opencontainers.image.description="A containerized MCP server implementation with HTTP/SSE transport for retrieving and processing documentation through vector search"
LABEL org.opencontainers.image.authors="Amir Arad"
LABEL org.opencontainers.image.url="https://github.com/amir-arad/mcp-ragdocs"
LABEL org.opencontainers.image.source="https://github.com/amir-arad/mcp-ragdocs"

# Set environment variables from docker-compose.yml
ENV NODE_OPTIONS="--experimental-fetch"
ENV DEBUG="pw:api"
ENV EMBEDDING_PROVIDER=ollama
ENV EMBEDDING_MODEL=nomic-embed-text
ENV QDRANT_URL=http://qdrant:6333
ENV PORT=3030
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Copy helper scripts
COPY wait-for-it.sh /app/wait-for-it.sh
COPY diagnostic.sh /app/diagnostic.sh
RUN chmod +x /app/wait-for-it.sh /app/diagnostic.sh

# Expose the port
EXPOSE 3030
EXPOSE 3031

# Start the application with proper error handling to prevent early exit
CMD ["/bin/bash", "-c", "/app/wait-for-it.sh qdrant:6333 -t 60 -- /app/wait-for-it.sh ollama:11434 -t 60 -- /app/diagnostic.sh && node build/index.js"]
