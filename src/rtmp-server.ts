/**
 * RTMP Server
 * Receives RTMP streams and triggers forwarding to configured providers
 */

import NodeMediaServer from 'node-media-server';
import { StreamForwarder } from './stream-forwarder';

export interface RTMPServerConfig {
  rtmpPort?: number;
  httpPort?: number;
  secret?: string;
}

export class RTMPServer {
  private server: NodeMediaServer | null = null;
  private streamForwarder: StreamForwarder;
  private config: RTMPServerConfig;

  constructor(streamForwarder: StreamForwarder, config: RTMPServerConfig = {}) {
    this.streamForwarder = streamForwarder;
    this.config = {
      rtmpPort: config.rtmpPort || 1935,
      httpPort: config.httpPort || 8000,
      secret: config.secret || ''
    };
  }

  /**
   * Start the RTMP server
   */
  start(): void {
    const nmsConfig = {
      rtmp: {
        port: this.config.rtmpPort,
        chunk_size: 60000,
        gop_cache: true,
        ping: 30,
        ping_timeout: 60
      },
      http: {
        port: this.config.httpPort,
        allow_origin: '*'
      }
    };

    this.server = new NodeMediaServer(nmsConfig);

    // Handle new stream published
    this.server.on('prePublish', (id, streamPath, args) => {
      console.log(`[RTMPServer] Stream publish attempt: ${streamPath}`);

      // Extract stream key from path (e.g., /live/streamkey -> streamkey)
      const streamKey = this.extractStreamKey(streamPath);

      if (!streamKey) {
        console.error('[RTMPServer] Invalid stream path, rejecting');
        return;
      }

      console.log(`[RTMPServer] Stream key: ${streamKey}`);
    });

    this.server.on('postPublish', (id, streamPath, args) => {
      console.log(`[RTMPServer] Stream published: ${streamPath}`);

      const streamKey = this.extractStreamKey(streamPath);

      if (streamKey) {
        // Construct the local RTMP URL for this stream
        const inputUrl = `rtmp://127.0.0.1:${this.config.rtmpPort}${streamPath}`;

        // Start forwarding to configured providers
        setTimeout(() => {
          this.streamForwarder.startForwarding(streamKey, inputUrl);
        }, 1000); // Small delay to ensure stream is fully established
      }
    });

    // Handle stream stopped
    this.server.on('donePublish', (id, streamPath, args) => {
      console.log(`[RTMPServer] Stream stopped: ${streamPath}`);

      const streamKey = this.extractStreamKey(streamPath);

      if (streamKey) {
        this.streamForwarder.stopForwarding(streamKey);
      }
    });

    this.server.run();
    console.log(`[RTMPServer] RTMP server started on port ${this.config.rtmpPort}`);
    console.log(`[RTMPServer] HTTP server started on port ${this.config.httpPort}`);
    console.log(`[RTMPServer] Publish streams to: rtmp://localhost:${this.config.rtmpPort}/live/{streamKey}`);
  }

  /**
   * Stop the RTMP server
   */
  stop(): void {
    if (this.server) {
      this.server.stop();
      console.log('[RTMPServer] Server stopped');
      this.server = null;
    }
  }

  /**
   * Extract stream key from RTMP path
   * Example: /live/mystream -> mystream
   */
  private extractStreamKey(streamPath: string): string | null {
    const parts = streamPath.split('/');
    if (parts.length >= 3) {
      return parts[2]; // /live/streamkey -> streamkey
    }
    return null;
  }

  /**
   * Get server configuration
   */
  getConfig(): RTMPServerConfig {
    return { ...this.config };
  }
}
