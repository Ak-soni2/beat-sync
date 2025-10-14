const os = require('os');
const http = require('http');
const express = require('express');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const PORT = process.env.SFU_PORT || 5001;

// Very small in-memory state for POC
const rooms = new Map();

async function createWorker() {
  const worker = await mediasoup.createWorker({
    rtcMinPort: 10000,
    rtcMaxPort: 10100,
  });
  worker.on('died', () => {
    console.error('mediasoup worker died, exiting in 2 seconds...');
    setTimeout(() => process.exit(1), 2000);
  });
  return worker;
}

(async () => {
  const worker = await createWorker();
  const router = await worker.createRouter({
    mediaCodecs: [
      {
        kind: 'audio',
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
      },
    ],
  });

  io.on('connection', socket => {
    console.log('client connected', socket.id);
    socket.transports = new Map();

    socket.on('joinRoom', ({roomId}, cb) => {
      if (!rooms.has(roomId)) rooms.set(roomId, { router, producers: new Map() });
      socket.join(roomId);
      cb({ rtpCapabilities: router.rtpCapabilities });
    });

    socket.on('createTransport', async ({roomId}, cb) => {
      try {
        const transport = await router.createWebRtcTransport({ 
          listenIps: [
            { ip: '172.31.8.85', announcedIp: null }, // Your computer's IP
            { ip: '0.0.0.0', announcedIp: '172.31.8.85' } // Listen on all interfaces, announce your IP
          ], 
          enableUdp: true, 
          enableTcp: true, 
          preferUdp: true 
        });
        socket.transports.set(transport.id, transport);
        cb({ id: transport.id, iceParameters: transport.iceParameters, iceCandidates: transport.iceCandidates, dtlsParameters: transport.dtlsParameters });
      } catch (err) {
        console.error(err); cb({ error: err.message });
      }
    });

    socket.on('connectTransport', async ({transportId, dtlsParameters}, cb) => {
      try {
        const transport = socket.transports.get(transportId);
        if (!transport) return cb({ error: 'transport not found' });
        await transport.connect({ dtlsParameters });
        cb({ connected: true });
      } catch (err) { cb({ error: err.message }); }
    });

    socket.on('produce', async ({transportId, kind, rtpParameters, roomId}, cb) => {
      try {
        const transport = socket.transports.get(transportId);
        if (!transport) return cb({ error: 'transport not found' });
        const producer = await transport.produce({ kind, rtpParameters });
        rooms.get(roomId).producers.set(producer.id, producer);
        cb({ id: producer.id });
      } catch (err) { cb({ error: err.message }); }
    });

    socket.on('getProducers', ({roomId}, cb) => {
      const producers = Array.from((rooms.get(roomId)?.producers||new Map()).keys());
      cb(producers);
    });

    socket.on('consume', async ({transportId, producerId, rtpCapabilities, roomId}, cb) => {
      try {
        console.log('consume request:', { transportId, producerId, roomId });
        const transport = socket.transports.get(transportId);
        if (!transport) return cb({ error: 'transport not found' });
        
        // Validate that the producer exists in the room
        const room = rooms.get(roomId);
        if (!room || !room.producers.has(producerId)) {
          return cb({ error: 'producer not found in room' });
        }
        
        const consumer = await transport.consume({ producerId, rtpCapabilities, paused: false });
        console.log('consumer created:', consumer.id);
        cb({ id: consumer.id, producerId, kind: consumer.kind, rtpParameters: consumer.rtpParameters });
      } catch (err) { 
        console.error('consume error:', err.message);
        cb({ error: err.message }); 
      }
    });

    socket.on('disconnect', () => {
      console.log('client disconnected', socket.id);
    });
  });

  server.listen(PORT, '0.0.0.0', () => console.log('mediasoup signaling server listening on', PORT, '(all interfaces)'));
})();
