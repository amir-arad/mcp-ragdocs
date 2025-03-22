import express from "express";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SessionManager } from "./services/session-manager.js";
import * as http from "http";

/**
 * Sets up and manages the HTTP server for the MCP RAG Docs service
 * Handles SSE connections and message routing
 */
export class HttpServer {
  private app: express.Application;
  private server: http.Server | null = null;
  private sessionManager: SessionManager;
  private mcpServer: Server;

  /**
   * Creates a new HTTP server
   * 
   * @param mcpServer The MCP server instance
   */
  constructor(mcpServer: Server) {
    this.app = express();
    this.mcpServer = mcpServer;
    this.sessionManager = new SessionManager(mcpServer, {
      inactivityThreshold: 30 * 60 * 1000, // 30 minutes
      cleanupInterval: 5 * 60 * 1000 // 5 minutes
    });

    this.setupRoutes();
  }


  /**
   * Sets up routes for the Express application
   */
  private setupRoutes() {
    // SSE endpoint
    this.app.get("/sse", async (req: any, res: any) => {
      try {
        // Create a new session
        const sessionId = await this.sessionManager.createSession("/messages", res);
        
        // Send the session ID as the first SSE message
        res.write(`event: session\ndata: ${JSON.stringify({ sessionId })}\n\n`);
        
        // Send the endpoint event with the full URI for sending messages
        const messageEndpoint = `/messages/${sessionId}`;
        res.write(`event: endpoint\ndata: ${messageEndpoint}\n\n`);
        
        // Set up connection close handler
        req.on('close', () => {
          console.log(`SSE connection closed for session: ${sessionId}`);
          this.sessionManager.removeSession(sessionId);
        });
        
        console.log(`SSE connection established for session: ${sessionId}`);
      } catch (error) {
        console.error("Error establishing SSE connection:", error);
        res.status(500).end();
      }
    });
    
    this.app.post("/messages", async (req: any, res: any) => {
      // Extract session ID from headers or query parameters
      const sessionId = req.headers['x-session-id'] || req.query.sessionId;
      
      if (!sessionId) {
        return res.status(400).json({ error: "Session ID is required" });
      }
      
      if (!this.sessionManager.hasSession(sessionId)) {
        return res.status(404).json({ error: "Session not found" });
      }
      
      const session = this.sessionManager.getSession(sessionId);
      if (session) {
        try {
          await session.transport.handlePostMessage(req, res);
        } catch (error) {
          console.error(`Error handling message for session ${sessionId}:`, error);
          res.status(500).json({ error: "Internal server error" });
        }
      } else {
        res.status(503).json({ error: "Session transport not available" });
      }
    });
    // Message endpoint for client to send messages
    this.app.post("/messages/:sessionId", async (req: any, res: any) => {
      const sessionId = req.params.sessionId;
      
      if (!this.sessionManager.hasSession(sessionId)) {
        return res.status(404).json({ error: "Session not found" });
      }
      
      const session = this.sessionManager.getSession(sessionId);
      if (session) {
        try {
          await session.transport.handlePostMessage(req, res);
        } catch (error) {
          console.error(`Error handling message for session ${sessionId}:`, error);
          res.status(500).json({ error: "Internal server error" });
        }
      } else {
        res.status(503).json({ error: "Session transport not available" });
      }
    });

    // Add status endpoint for monitoring
    this.app.get("/status", (req: any, res: any) => {
      res.json({
        status: "ok",
        activeSessions: this.sessionManager.getActiveSessions(),
        uptime: process.uptime(),
        memory: process.memoryUsage()
      });
    });
  }

  /**
   * Starts the HTTP server
   * 
   * @param port The port to listen on
   * @returns A promise that resolves when the server is started
   */
  async start(port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      this.server = this.app.listen(port, '0.0.0.0', () => {
        console.log(`HTTP server running on port ${port}, process ID: ${process.pid}`);
        resolve();
      });
      
      this.server.on('error', (error: any) => {
        console.error(`Failed to start HTTP server on port ${port}:`, error);
        reject(error);
      });
    });
  }

  /**
   * Stops the HTTP server and cleans up resources
   */
  async stop(): Promise<void> {
    await this.sessionManager.cleanup();
    
    if (this.server) {
      await new Promise((resolve) => {
        if (!this.server) return resolve(void 0);
        this.server.close(resolve);
      });
      console.log("HTTP server stopped");
      this.server = null;
    }
  }

  /**
   * Gets the number of active sessions
   * 
   * @returns The number of active sessions
   */
  getActiveSessions(): number {
    return this.sessionManager.getActiveSessions();
  }
}