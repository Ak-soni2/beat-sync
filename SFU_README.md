Mediasoup prototype for SilentStream

This is a minimal proof-of-concept to demonstrate a 1->N SFU using mediasoup.

Files added:
- server/mediasoupServer.js - small mediasoup worker + Socket.IO signaling server (POC)
- public/sfu-broadcast.html - broadcaster page (POC)
- public/sfu-listen.html - listener page (POC)
- public/js/sfu-broadcast.js - broadcaster client logic
- public/js/sfu-listen.js - listener client logic

Notes and setup
1. Install dependencies (mediasoup needs native build tools on Windows; use WSL for best results):

```powershell
cd C:\Users\91798\SilentStream
npm install mediasoup socket.io
# For client bundling, we used CDN for mediasoup-client in this POC
```

2. Start the mediasoup signaling server:

```powershell
node server/mediasoupServer.js
```

3. Open the POC pages in a browser (on the same machine):
- http://localhost:5000/sfu-broadcast.html (click Start Broadcast)
- http://localhost:5000/sfu-listen.html (click Start Listening)

Limitations
- This is a small POC. It uses loopback IPs for mediasoup transports and a naive implementation. For production you must:
  - Use proper listenIps (public IPs) and ICE servers (STUN/TURN)
  - Add authentication and room safety
  - Scale mediasoup workers and use Redis for coordination
  - Properly handle lifecycle of transports, producers, and consumers

I can proceed to:
- Wire the POC into your existing app (replace current PeerJS pages with SFU versions),
- Improve server to use real public listen IPs and TURN,
- Add a small bundling step for mediasoup-client instead of CDN, or
- Implement scaling/Redis coordination.

Which would you like next?