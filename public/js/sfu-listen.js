import * as mediasoupClient from '/node_modules/mediasoup-client/lib/index.js';

const socket = io('http://localhost:5001');
socket.on('connect_error', (err) => console.error('Socket connect error', err));
socket.on('connect', () => console.log('Socket connected to mediasoup signaling'));
let device;

document.getElementById('start').addEventListener('click', async () => {
  const roomId = 'poc_room';
  const { rtpCapabilities } = await new Promise(resolve => socket.emit('joinRoom', { roomId }, resolve));
  device = new mediasoupClient.Device();
  await device.load({ routerRtpCapabilities: rtpCapabilities });

  // get producers
  const { producers } = await new Promise(resolve => socket.emit('getProducers', { roomId }, resolve));
  if (!producers || producers.length === 0) return console.log('no producers');
  const producerId = producers[0];
  // create receive transport on server
  const transportInfo = await new Promise(resolve => socket.emit('createTransport', { roomId }, resolve));
  const recvTransport = device.createRecvTransport({ id: transportInfo.id, iceParameters: transportInfo.iceParameters, iceCandidates: transportInfo.iceCandidates, dtlsParameters: transportInfo.dtlsParameters });

  recvTransport.on('connect', ({ dtlsParameters }, callback, errback) => {
    socket.emit('connectTransport', { transportId: transportInfo.id, dtlsParameters }, res => {
      if (res && res.error) return errback(res.error);
      callback();
    });
  });

  // ask server to create a consumer
  const consumeInfo = await new Promise(resolve => socket.emit('consume', { transportId: transportInfo.id, producerId, rtpCapabilities: device.rtpCapabilities }, resolve));
  if (consumeInfo.error) return console.error(consumeInfo.error);

  const consumer = await recvTransport.consume({ id: consumeInfo.id, producerId: consumeInfo.producerId, kind: consumeInfo.kind, rtpParameters: consumeInfo.rtpParameters });
  const stream = new MediaStream();
  stream.addTrack(consumer.track);
  const audioEl = document.getElementById('audio');
  audioEl.srcObject = stream;
  audioEl.play().catch(e => console.warn('play failed', e));
  console.log('consuming audio');
});
