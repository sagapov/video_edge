/**
 * REST API Server
 * Provides endpoints to manage stream configurations
 */

import express, { Express, Request, Response } from 'express';
import { ConfigManager } from './config-manager';
import { StreamForwarder } from './stream-forwarder';

export class ApiServer {
  private app: Express;
  private configManager: ConfigManager;
  private streamForwarder: StreamForwarder;
  private port: number;

  constructor(configManager: ConfigManager, streamForwarder: StreamForwarder, port: number = 3000) {
    this.app = express();
    this.configManager = configManager;
    this.streamForwarder = streamForwarder;
    this.port = port;

    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    this.app.use(express.json());

    // Request logging
    this.app.use((req, res, next) => {
      console.log(`[API] ${req.method} ${req.path}`);
      next();
    });
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/health', (req: Request, res: Response) => {
      res.json({ status: 'ok', timestamp: new Date().toISOString() });
    });

    // Get all configurations
    this.app.get('/api/config', (req: Request, res: Response) => {
      const configs = this.configManager.getAllConfigs();
      res.json(configs);
    });

    // Set default providers
    this.app.post('/api/config/defaults', (req: Request, res: Response) => {
      const { urls } = req.body;

      if (!urls || !Array.isArray(urls)) {
        return res.status(400).json({ error: 'urls must be an array of strings' });
      }

      this.configManager.setDefaultProviders(urls);
      res.json({
        success: true,
        defaults: this.configManager.getDefaultProviders()
      });
    });

    // Get default providers
    this.app.get('/api/config/defaults', (req: Request, res: Response) => {
      res.json({ defaults: this.configManager.getDefaultProviders() });
    });

    // Set stream-specific providers
    this.app.post('/api/config/streams/:streamKey', (req: Request, res: Response) => {
      const { streamKey } = req.params;
      const { urls } = req.body;

      if (!urls || !Array.isArray(urls)) {
        return res.status(400).json({ error: 'urls must be an array of strings' });
      }

      this.configManager.setStreamProviders(streamKey, urls);
      res.json({
        success: true,
        streamKey,
        providers: this.configManager.getStreamProviders(streamKey)
      });
    });

    // Get stream-specific providers
    this.app.get('/api/config/streams/:streamKey', (req: Request, res: Response) => {
      const { streamKey } = req.params;
      res.json({
        streamKey,
        providers: this.configManager.getStreamProviders(streamKey)
      });
    });

    // Delete stream-specific configuration
    this.app.delete('/api/config/streams/:streamKey', (req: Request, res: Response) => {
      const { streamKey } = req.params;
      const removed = this.configManager.removeStreamConfig(streamKey);

      if (removed) {
        res.json({ success: true, streamKey });
      } else {
        res.status(404).json({ error: 'Stream configuration not found' });
      }
    });

    // Get active streams
    this.app.get('/api/streams/active', (req: Request, res: Response) => {
      const activeStreams = this.streamForwarder.getActiveStreams();
      res.json({
        count: activeStreams.length,
        streams: activeStreams
      });
    });

    // Stop a specific stream
    this.app.post('/api/streams/:streamKey/stop', (req: Request, res: Response) => {
      const { streamKey } = req.params;
      const stopped = this.streamForwarder.stopForwarding(streamKey);

      if (stopped) {
        res.json({ success: true, streamKey });
      } else {
        res.status(404).json({ error: 'Stream not found or not active' });
      }
    });

    // API documentation
    this.app.get('/api', (req: Request, res: Response) => {
      res.json({
        version: '1.0.0',
        endpoints: {
          'GET /health': 'Health check',
          'GET /api': 'API documentation',
          'GET /api/config': 'Get all configurations',
          'POST /api/config/defaults': 'Set default provider URLs',
          'GET /api/config/defaults': 'Get default provider URLs',
          'POST /api/config/streams/:streamKey': 'Set providers for specific stream',
          'GET /api/config/streams/:streamKey': 'Get providers for specific stream',
          'DELETE /api/config/streams/:streamKey': 'Remove stream-specific configuration',
          'GET /api/streams/active': 'Get list of active streams',
          'POST /api/streams/:streamKey/stop': 'Stop forwarding a stream'
        }
      });
    });
  }

  /**
   * Start the API server
   */
  start(): void {
    this.app.listen(this.port, () => {
      console.log(`[API] Server listening on port ${this.port}`);
      console.log(`[API] API documentation: http://localhost:${this.port}/api`);
    });
  }
}
