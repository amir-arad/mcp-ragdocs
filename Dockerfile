# Stage 1: Build the TypeScript project
FROM node:20-bullseye AS builder

# Set working directory
WORKDIR /app

# Install system dependencies for Playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libpango-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    libxss1 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Copy package files and install dependencies
COPY package*.json ./

# Modify the package.json to temporarily disable the prepare script to avoid circular dependency
RUN sed -i 's/"prepare": "npm run build",/"prepare": "echo Skipping prepare script during Docker build",/g' package.json
RUN npm install

# Copy source code
COPY . .

# Build TypeScript code manually
RUN npm run build

# Stage 2: Production image
FROM node:20-bullseye

# Set working directory
WORKDIR /app

# Install system dependencies for Playwright and additional utilities for diagnostics
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libpango-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    libxss1 \
    xvfb iputils-ping curl wget netcat dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy built files from builder stage
COPY --from=builder /app/build /app/build
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/package.json /app/package.json

# Copy public files to both potential locations
COPY --from=builder /app/src/public /app/build/public
COPY --from=builder /app/src/public /app/src/public

# Install Playwright browser
ENV PLAYWRIGHT_BROWSERS_PATH=/app/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0
RUN npx playwright install chromium
RUN npx playwright install-deps chromium

# Set environment variables from docker-compose.yml
ENV NODE_OPTIONS="--experimental-fetch"
ENV DEBUG="pw:api"
ENV EMBEDDING_PROVIDER=ollama
ENV EMBEDDING_MODEL=nomic-embed-text
ENV QDRANT_URL=http://qdrant:6333
ENV PORT=3030

# Copy helper scripts
COPY wait-for-it.sh /app/wait-for-it.sh
COPY diagnostic.sh /app/diagnostic.sh
RUN chmod +x /app/wait-for-it.sh /app/diagnostic.sh

# Expose the port
EXPOSE 3030
EXPOSE 3031

# Start the application with proper error handling to prevent early exit
CMD ["/bin/bash", "-c", "/app/wait-for-it.sh qdrant:6333 -t 60 -- /app/diagnostic.sh && node build/index.js"]
