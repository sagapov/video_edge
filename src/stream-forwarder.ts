/**
 * Stream Forwarder
 * Forwards RTMP streams to multiple streaming providers using FFmpeg
 */

import ffmpeg from 'fluent-ffmpeg';
import { ConfigManager } from './config-manager';

export interface ActiveStream {
  streamKey: string;
  inputUrl: string;
  providers: string[];
  processes: any[];
  startTime: Date;
}

export class StreamForwarder {
  private configManager: ConfigManager;
  private activeStreams: Map<string, ActiveStream> = new Map();

  constructor(configManager: ConfigManager) {
    this.configManager = configManager;
  }

  /**
   * Start forwarding a stream to configured providers
   */
  startForwarding(streamKey: string, inputUrl: string): void {
    // Check if already forwarding
    if (this.activeStreams.has(streamKey)) {
      console.log(`[StreamForwarder] Stream '${streamKey}' is already being forwarded`);
      return;
    }

    const providers = this.configManager.getStreamProviders(streamKey);

    if (providers.length === 0) {
      console.warn(`[StreamForwarder] No providers configured for stream '${streamKey}'`);
      return;
    }

    console.log(`[StreamForwarder] Starting forwarding for '${streamKey}' to ${providers.length} provider(s)`);

    const processes: any[] = [];

    // Create a separate FFmpeg process for each provider
    providers.forEach((providerUrl, index) => {
      try {
        console.log(`[StreamForwarder] Forwarding '${streamKey}' to provider ${index + 1}: ${providerUrl}`);

        const process = ffmpeg(inputUrl)
          .inputOptions([
            '-re',  // Read input at native frame rate
            '-i', inputUrl
          ])
          .outputOptions([
            '-c copy',  // Copy codec (no re-encoding)
            '-f flv'    // Output format FLV for RTMP
          ])
          .output(providerUrl)
          .on('start', (commandLine) => {
            console.log(`[StreamForwarder] FFmpeg started for provider ${index + 1}: ${commandLine}`);
          })
          .on('error', (err) => {
            console.error(`[StreamForwarder] Error forwarding '${streamKey}' to provider ${index + 1}:`, err.message);
          })
          .on('end', () => {
            console.log(`[StreamForwarder] Forwarding ended for '${streamKey}' to provider ${index + 1}`);
          });

        process.run();
        processes.push(process);
      } catch (error: any) {
        console.error(`[StreamForwarder] Failed to start forwarding to provider ${index + 1}:`, error.message);
      }
    });

    // Store active stream info
    this.activeStreams.set(streamKey, {
      streamKey,
      inputUrl,
      providers,
      processes,
      startTime: new Date()
    });
  }

  /**
   * Stop forwarding a stream
   */
  stopForwarding(streamKey: string): boolean {
    const activeStream = this.activeStreams.get(streamKey);

    if (!activeStream) {
      console.log(`[StreamForwarder] Stream '${streamKey}' is not being forwarded`);
      return false;
    }

    console.log(`[StreamForwarder] Stopping forwarding for '${streamKey}'`);

    // Kill all FFmpeg processes for this stream
    activeStream.processes.forEach((process, index) => {
      try {
        process.kill('SIGKILL');
        console.log(`[StreamForwarder] Stopped forwarding to provider ${index + 1}`);
      } catch (error: any) {
        console.error(`[StreamForwarder] Error stopping provider ${index + 1}:`, error.message);
      }
    });

    this.activeStreams.delete(streamKey);
    return true;
  }

  /**
   * Get list of active streams
   */
  getActiveStreams(): ActiveStream[] {
    return Array.from(this.activeStreams.values()).map(stream => ({
      streamKey: stream.streamKey,
      inputUrl: stream.inputUrl,
      providers: stream.providers,
      processes: [], // Don't expose process objects
      startTime: stream.startTime
    }));
  }

  /**
   * Check if a stream is active
   */
  isActive(streamKey: string): boolean {
    return this.activeStreams.has(streamKey);
  }

  /**
   * Stop all active streams
   */
  stopAll(): void {
    console.log('[StreamForwarder] Stopping all active streams');
    const streamKeys = Array.from(this.activeStreams.keys());
    streamKeys.forEach(key => this.stopForwarding(key));
  }
}
