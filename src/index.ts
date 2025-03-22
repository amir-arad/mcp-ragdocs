#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { ApiClient } from "./api-client.js";
import { HandlerRegistry } from "./handler-registry.js";
import { HttpServer } from "./http-server.js";
import { WebInterface } from "./server.js";

const COLLECTION_NAME = "documentation";
const HTTP_PORT = 3031;

class RagDocsServer {
  private server: Server;
  private apiClient: ApiClient;
  private handlerRegistry: HandlerRegistry;
  private httpServer: HttpServer;
  private webInterface: WebInterface;

  constructor() {
    this.server = new Server(
      {
        name: "mcp-ragdocs",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.apiClient = new ApiClient();
    this.handlerRegistry = new HandlerRegistry(this.server, this.apiClient);
    this.httpServer = new HttpServer(this.server);
    this.webInterface = new WebInterface(this.apiClient);

    // Error handling
    this.server.onerror = (error) => console.error("[MCP Error]", error);
    process.on("SIGINT", async () => {
      console.log("Received SIGINT signal, cleaning up...");
      await this.cleanup();
      process.exit(0);
    });
    process.on("SIGTERM", async () => {
      console.log("Received SIGTERM signal, cleaning up...");
      await this.cleanup();
      process.exit(0);
    });
  }

  private async cleanup() {
    await this.apiClient.cleanup();
    await this.webInterface.stop();
    await this.httpServer.stop();
    await this.server.close();
  }

  async run() {
    try {
      // Initialize Qdrant collection
      console.log("Initializing Qdrant collection...");
      await this.apiClient.initCollection(COLLECTION_NAME);
      console.log("Qdrant collection initialized successfully");

      // Start web interface
      await this.webInterface.start();
      console.log("Web interface is running");

      // Start HTTP server for SSE
      await this.httpServer.start(HTTP_PORT);
      console.log(`RAG Docs MCP server running on HTTP/SSE, port: ${HTTP_PORT}, process ID: ${process.pid}`);
      
      // Add keep-alive to prevent container from exiting
      console.log("Setting up keep-alive interval to prevent container exit");
      setInterval(() => {
        const memUsage = process.memoryUsage();
        console.log(`[KEEP-ALIVE] ${new Date().toISOString()} - Service running, memory usage: ${
          Math.round(memUsage.rss / 1024 / 1024)
        }MB RSS, ${Math.round(memUsage.heapUsed / 1024 / 1024)}MB heap, active sessions: ${this.httpServer.getActiveSessions()}`);
      }, 60000); // Log every minute to keep process alive and provide monitoring info
      
    } catch (error) {
      console.error("Failed to initialize server:", error);
      process.exit(1);
    }
  }
}

const server = new RagDocsServer();
server.run().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
