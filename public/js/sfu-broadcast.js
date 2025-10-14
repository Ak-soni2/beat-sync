import * as mediasoupClient from '/node_modules/mediasoup-client/lib/index.js';

const socket = io('http://localhost:5001');
socket.on('connect_error', (err) => console.error('Socket connect error', err));
socket.on('connect', () => console.log('Socket connected to mediasoup signaling'));
let device;
let sendTransport;

document.getElementById('start').addEventListener('click', async () => {
  const roomId = 'poc_room';
  const { rtpCapabilities } = await new Promise(resolve => socket.emit('joinRoom', { roomId }, resolve));
  device = new mediasoupClient.Device();
  await device.load({ routerRtpCapabilities: rtpCapabilities });

  // create send transport
  const transportInfo = await new Promise(resolve => socket.emit('createTransport', { roomId }, resolve));
  sendTransport = device.createSendTransport({ id: transportInfo.id, iceParameters: transportInfo.iceParameters, iceCandidates: transportInfo.iceCandidates, dtlsParameters: transportInfo.dtlsParameters });

  sendTransport.on('connect', ({ dtlsParameters }, callback, errback) => {
    socket.emit('connectTransport', { transportId: transportInfo.id, dtlsParameters }, res => {
      if (res && res.error) return errback(res.error);
      callback();
    });
  });

  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const track = stream.getAudioTracks()[0];
  const producer = await sendTransport.produce({ track });
  await new Promise(resolve => socket.emit('produce', { transportId: transportInfo.id, kind: 'audio', rtpParameters: producer.rtpParameters, roomId }, resolve));
  console.log('producing audio');
});
