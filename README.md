# Video Edge Service

A simple RTMP video edge service that receives streams and forwards them to multiple streaming providers.

## Features

- **RTMP Ingestion**: Receive RTMP streams on a configurable port
- **Multi-Provider Forwarding**: Forward streams to multiple streaming platforms simultaneously
- **Per-Stream Configuration**: Configure different provider URLs for each stream
- **Default Fallback**: Use default providers when no stream-specific config exists
- **REST API**: Simple API to manage configurations dynamically
- **Zero Re-encoding**: Streams are copied without transcoding for minimal latency

## Requirements

- Node.js 18+
- FFmpeg installed on the system (required for stream forwarding)

## Installation

```bash
npm install
```

## Building

```bash
npm run build
```

## Running

### Development Mode

```bash
npm run dev
```

### Production Mode

```bash
npm run build
npm start
```

### Using Docker

```bash
# Build and run with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

Or build and run manually:

```bash
# Build image
docker build -t video-edge-service .

# Run container
docker run -d \
  -p 1935:1935 \
  -p 3000:3000 \
  -p 8000:8000 \
  --name video-edge \
  video-edge-service
```

## Configuration

### Environment Variables

- `RTMP_PORT`: RTMP server port (default: 1935)
- `HTTP_PORT`: HTTP server port (default: 8000)
- `API_PORT`: API server port (default: 3000)
- `DEFAULT_PROVIDERS`: Comma-separated list of default RTMP URLs

Example:

```bash
export RTMP_PORT=1935
export API_PORT=3000
export DEFAULT_PROVIDERS="rtmp://live.twitch.tv/app/your_key,rtmp://a.rtmp.youtube.com/live2/your_key"
npm start
```

## Usage

### Publishing Streams

Publish your RTMP stream to:

```
rtmp://localhost:1935/live/{streamKey}
```

Example with OBS Studio:
- Server: `rtmp://localhost:1935/live`
- Stream Key: `mystream`

Example with FFmpeg:

```bash
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream
```

### REST API

#### Get API Documentation

```bash
curl http://localhost:3000/api
```

#### Set Default Providers

```bash
curl -X POST http://localhost:3000/api/config/defaults \
  -H "Content-Type: application/json" \
  -d '{
    "urls": [
      "rtmp://live.twitch.tv/app/YOUR_STREAM_KEY",
      "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY"
    ]
  }'
```

#### Get Default Providers

```bash
curl http://localhost:3000/api/config/defaults
```

#### Set Stream-Specific Providers

```bash
curl -X POST http://localhost:3000/api/config/streams/mystream \
  -H "Content-Type: application/json" \
  -d '{
    "urls": [
      "rtmp://live.twitch.tv/app/STREAM_KEY_1",
      "rtmp://live-api-s.facebook.com:80/rtmp/STREAM_KEY_2"
    ]
  }'
```

#### Get Stream Configuration

```bash
curl http://localhost:3000/api/config/streams/mystream
```

#### Delete Stream Configuration

```bash
curl -X DELETE http://localhost:3000/api/config/streams/mystream
```

#### Get All Configurations

```bash
curl http://localhost:3000/api/config
```

#### Get Active Streams

```bash
curl http://localhost:3000/api/streams/active
```

#### Stop a Stream

```bash
curl -X POST http://localhost:3000/api/streams/mystream/stop
```

## Example Workflow

1. **Start the service**:
   ```bash
   npm start
   ```

2. **Configure default providers** (optional):
   ```bash
   curl -X POST http://localhost:3000/api/config/defaults \
     -H "Content-Type: application/json" \
     -d '{"urls": ["rtmp://provider1.com/app/key1"]}'
   ```

3. **Configure stream-specific providers**:
   ```bash
   curl -X POST http://localhost:3000/api/config/streams/event1 \
     -H "Content-Type: application/json" \
     -d '{
       "urls": [
         "rtmp://live.twitch.tv/app/YOUR_KEY",
         "rtmp://a.rtmp.youtube.com/live2/YOUR_KEY"
       ]
     }'
   ```

4. **Start streaming** to `rtmp://localhost:1935/live/event1`

5. **Monitor active streams**:
   ```bash
   curl http://localhost:3000/api/streams/active
   ```

## Architecture

```
┌─────────────┐
│   RTMP      │
│  Publisher  │
│  (OBS, etc) │
└──────┬──────┘
       │
       │ RTMP Stream
       ▼
┌─────────────────┐
│  RTMP Server    │
│  (port 1935)    │
└────────┬────────┘
         │
         │ Triggers
         ▼
┌──────────────────┐      ┌──────────────────┐
│ Stream Forwarder │◄─────┤ Config Manager   │
│  (FFmpeg)        │      │                  │
└────────┬─────────┘      └────────▲─────────┘
         │                         │
         │ Forwards to             │ Managed by
         │ Multiple                │
         │ Providers               │
         ▼                         │
┌─────────────────┐         ┌──────────────┐
│  Provider 1     │         │  REST API    │
│  (Twitch, etc)  │         │ (port 3000)  │
├─────────────────┤         └──────────────┘
│  Provider 2     │
│  (YouTube, etc) │
├─────────────────┤
│  Provider N     │
└─────────────────┘
```

## Components

- **ConfigManager**: Manages default and per-stream provider configurations
- **RTMPServer**: Receives incoming RTMP streams
- **StreamForwarder**: Uses FFmpeg to forward streams to multiple providers
- **ApiServer**: Provides REST API for configuration management

## License

MIT
