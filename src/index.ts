/**
 * Video Edge Service
 * Main entry point
 */

import { ConfigManager } from './config-manager';
import { StreamForwarder } from './stream-forwarder';
import { RTMPServer } from './rtmp-server';
import { ApiServer } from './api-server';

// Configuration
const RTMP_PORT = parseInt(process.env.RTMP_PORT || '1935');
const HTTP_PORT = parseInt(process.env.HTTP_PORT || '8000');
const API_PORT = parseInt(process.env.API_PORT || '3000');

// Initialize components
const configManager = new ConfigManager();
const streamForwarder = new StreamForwarder(configManager);
const rtmpServer = new RTMPServer(streamForwarder, {
  rtmpPort: RTMP_PORT,
  httpPort: HTTP_PORT
});
const apiServer = new ApiServer(configManager, streamForwarder, API_PORT);

// Set default providers from environment (if provided)
const defaultProviders = process.env.DEFAULT_PROVIDERS?.split(',').filter(p => p.trim()) || [];
if (defaultProviders.length > 0) {
  configManager.setDefaultProviders(defaultProviders);
  console.log(`[Main] Default providers configured from environment: ${defaultProviders.join(', ')}`);
}

// Graceful shutdown
const shutdown = () => {
  console.log('\n[Main] Shutting down...');
  streamForwarder.stopAll();
  rtmpServer.stop();
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Start services
console.log('='.repeat(60));
console.log('Video Edge Service');
console.log('='.repeat(60));
console.log(`RTMP Port: ${RTMP_PORT}`);
console.log(`HTTP Port: ${HTTP_PORT}`);
console.log(`API Port: ${API_PORT}`);
console.log('='.repeat(60));

rtmpServer.start();
apiServer.start();

console.log('\n[Main] Service started successfully');
console.log(`[Main] Publish RTMP streams to: rtmp://localhost:${RTMP_PORT}/live/{streamKey}`);
console.log(`[Main] API available at: http://localhost:${API_PORT}/api`);
console.log(`[Main] Use Ctrl+C to stop\n`);
