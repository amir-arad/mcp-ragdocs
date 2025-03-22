#!/bin/bash
echo "Starting Ollama server..."
ollama serve &
SERVE_PID=$!
echo "Waiting for Ollama server to be active..."
while ! ollama list | grep -q 'NAME'; do
  sleep 1
done
echo "Pulling nomic-embed-text model..."
ollama pull nomic-embed-text
echo "Model pulled successfully!"
wait $SERVE_PID