# SilentStream

A web-based audio streaming application for low-latency broadcasting. This project includes two implementations:

1. **Peer-to-Peer (P2P) Version** - Simple mesh networking using PeerJS for small-scale streaming
2. **Selective Forwarding Unit (SFU) Version** - Scalable broadcasting using mediasoup for one-to-many streaming

## Features

- **Multiple Audio Sources**: Choose between microphone input or media file playback
- **Device Selection**: Select specific microphone devices
- **Mobile Support**: Works on mobile devices over local network
- **Low Latency**: WebRTC-based streaming for real-time audio
- **Scalable Architecture**: SFU version supports many listeners per broadcaster

## Prerequisites

- [Node.js](https://nodejs.org/) (v20.13.1 or later recommended)
- Windows PowerShell (or compatible terminal)
- Modern web browser with WebRTC support

## Installation

1. **Clone or download the repository**
2. **Install dependencies:**
   `powershell
   cd SilentStream
   npm install
   `
3. **Install SFU-specific dependencies:**
   `powershell
   npm install mediasoup@3 socket.io@2.5.1
   npm install --save-dev webpack webpack-cli events
   `

## Usage

### P2P Version (PeerJS) - Small Scale

Best for few-to-few streaming scenarios.

1. **Start the application:**
   `powershell
   node app.js
   `
   Server starts on http://localhost:5000 with PeerServer on port 9000.

2. **Open in browser:**
   - **Broadcaster:** http://localhost:5000/broadcast.html
   - **Listener:** http://localhost:5000/listen.html

### SFU Version (mediasoup) - Scalable

Best for one-to-many broadcasting scenarios.

1. **Start the mediasoup SFU server:**
   `powershell
   node server/mediasoupServer.js
   `
   SFU server starts on port 5001.

2. **Start the main application server (in new terminal):**
   `powershell
   node app.js
   `
   Web server starts on port 5000.

3. **Open in browser:**
   - **SFU Broadcaster:** http://localhost:5000/sfu-broadcast.html
   - **SFU Listener:** http://localhost:5000/sfu-listen.html

## Mobile Device Access

To use on mobile devices, replace localhost with your computer's IP address:

1. **Find your IP address:**
   `powershell
   ipconfig | findstr "IPv4"
   `

2. **Mobile URLs (replace with your actual IP):**
   - SFU Broadcaster: http://YOUR_IP:5000/sfu-broadcast.html
   - SFU Listener: http://YOUR_IP:5000/sfu-listen.html

## Audio Source Options

Both versions support two audio capture modes:

### Microphone Mode
- Select from available microphone devices
- Real-time audio capture
- Configurable audio settings (no AGC, echo cancellation off for better quality)

### Media File Mode
- Upload audio or video files
- Uses HTMLMediaElement.captureStream() to avoid microphone feedback
- Supports common audio/video formats
- **Recommended** when playing audio on the same device to prevent audio loopback

## Development

### Building SFU Client Bundles

If you modify the SFU client code, rebuild the webpack bundles:

`powershell
npx webpack --config webpack.config.js
`

### File Structure

`
SilentStream/
 app.js                          # Main Express server + PeerJS
 server/
    mediasoupServer.js         # SFU server with mediasoup
 src/
    sfu-broadcast-entry.js     # SFU broadcaster client logic
    sfu-listen-entry.js        # SFU listener client logic
 public/
    broadcast.html             # P2P broadcaster page
    listen.html                # P2P listener page
    sfu-broadcast.html         # SFU broadcaster page
    sfu-listen.html            # SFU listener page
    js/
       broadcast.js           # P2P client logic
    dist/                      # Webpack bundles
        sfu-broadcast.bundle.js
        sfu-listen.bundle.js
 views/
    error.pug                  # Error page template
 webpack.config.js              # Webpack configuration
`

## Network Configuration

### Ports Used
- **5000**: Main web server (HTTP)
- **5001**: mediasoup SFU server (Socket.IO + WebRTC signaling)
- **9000**: PeerJS signaling server
- **10000-10100**: mediasoup WebRTC media ports (UDP/TCP)

### Firewall Settings
For mobile access, ensure Windows Firewall allows:
- Inbound connections on ports 5000, 5001, 9000
- UDP/TCP traffic on ports 10000-10100 (for WebRTC media)

## Troubleshooting

### Audio Loopback Issues
If you hear feedback when broadcasting from the same device:
1. Use **Media File Mode** instead of microphone
2. Use headphones for monitoring
3. Install audio loopback software:
   - **Windows**: [LoopBeAudio](https://www.nerds.de/en/loopbeaudio.html)
   - **macOS**: [BlackHole](https://github.com/ExistentialAudio/BlackHole)

### Connection Issues
- Check that all required ports are open
- Verify IP addresses are correct for mobile access
- Ensure devices are on the same WiFi network
- Check browser console for WebRTC connection errors

### Build Issues
- Run 
pm install to ensure all dependencies are installed
- For SFU version, rebuild bundles with 
px webpack --config webpack.config.js
- Check Node.js version (v20+ recommended)

## Architecture Notes

### P2P vs SFU Comparison

| Feature | P2P (PeerJS) | SFU (mediasoup) |
|---------|-------------|-----------------|
| Scalability | Limited (mesh network) | High (server relays) |
| Latency | Very low | Low |
| Server Resources | Minimal | Moderate |
| Best For | Small groups | Broadcasting |
| Max Listeners | ~10 | 100+ |

### Technology Stack
- **Frontend**: Vanilla JavaScript, WebRTC APIs
- **Backend**: Node.js, Express
- **P2P Signaling**: PeerJS
- **SFU Media**: mediasoup v3
- **SFU Signaling**: Socket.IO v2.5.1
- **Build**: Webpack v5
- **Templates**: Pug

## License

This project builds upon the original SilentStream by Elliott Woods, enhanced with SFU architecture and improved mobile support.
