import * as mediasoupClient from 'mediasoup-client';
window.mediasoupClient = mediasoupClient;

// Listener logic
const socket = io('http://172.31.8.85:5001');
socket.on('connect_error', (err) => console.error('Socket connect error', err));
socket.on('connect', () => console.log('Socket connected to mediasoup signaling'));
let device;
let recvTransport;

document.getElementById('start').addEventListener('click', async () => {
  const roomId = 'poc_room';
  const { rtpCapabilities } = await new Promise(resolve => socket.emit('joinRoom', { roomId }, resolve));
  device = new mediasoupClient.Device();
  await device.load({ routerRtpCapabilities: rtpCapabilities });

  const producers = await new Promise(resolve => socket.emit('getProducers', { roomId }, resolve));
  if (!producers || producers.length === 0) return alert('No broadcasters in room');

  const transportInfo = await new Promise(resolve => socket.emit('createTransport', { roomId }, resolve));
  recvTransport = device.createRecvTransport({ id: transportInfo.id, iceParameters: transportInfo.iceParameters, iceCandidates: transportInfo.iceCandidates, dtlsParameters: transportInfo.dtlsParameters });

  recvTransport.on('connect', ({ dtlsParameters }, callback, errback) => {
    socket.emit('connectTransport', { transportId: transportInfo.id, dtlsParameters }, res => {
      if (res && res.error) return errback(res.error);
      callback();
    });
  });

  const consumerData = await new Promise(resolve => socket.emit('consume', { transportId: transportInfo.id, producerId: producers[0], rtpCapabilities: device.rtpCapabilities, roomId }, resolve));
  if (consumerData && consumerData.error) {
    console.error('Consume failed:', consumerData.error);
    return alert('Failed to consume audio: ' + consumerData.error);
  }
  if (!consumerData || !consumerData.id) {
    console.error('Invalid consumer data:', consumerData);
    return alert('Failed to get consumer data');
  }
  const consumer = await recvTransport.consume({ id: consumerData.id, producerId: consumerData.producerId, kind: consumerData.kind, rtpParameters: consumerData.rtpParameters });
  const audio = document.getElementById('audio');
  audio.srcObject = new MediaStream([consumer.track]);
  audio.play();
  console.log('consuming audio');
});
