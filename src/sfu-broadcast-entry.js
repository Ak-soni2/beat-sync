import * as mediasoupClient from 'mediasoup-client';
window.mediasoupClient = mediasoupClient;

// Broadcaster logic
const socket = io('http://172.31.8.85:5001');
socket.on('connect_error', (err) => console.error('Socket connect error', err));
socket.on('connect', () => console.log('Socket connected to mediasoup signaling'));
let device;
let sendTransport;

// Enumerate audio devices on page load
async function enumerateDevices() {
  try {
    const allDevices = await navigator.mediaDevices.enumerateDevices();
    let deviceIndex = 0;
    const selector = document.getElementById('input_device_selector');
    
    for (let device of allDevices) {
      if (device.kind === 'audioinput') {
        const option = document.createElement('option');
        option.value = device.deviceId;
        option.text = device.label || `Input #${deviceIndex}`;
        selector.appendChild(option);
        deviceIndex++;
      }
    }
  } catch (err) {
    console.warn('Could not enumerate devices:', err);
  }
}

// UI: toggle capture source options (mic vs media file)
document.querySelectorAll('input[name="capture_source"]').forEach(radio => {
  radio.addEventListener('change', (e) => {
    const v = e.target.value;
    const micOpts = document.getElementById('mic_options');
    const mediaOpts = document.getElementById('media_options');
    if (micOpts) micOpts.style.display = v === 'mic' ? 'block' : 'none';
    if (mediaOpts) mediaOpts.style.display = v === 'media' ? 'block' : 'none';
  });
});

// Load selected media file into audio/video element so captureStream() has content
const mediaFileInput = document.getElementById('mediaFile');
if (mediaFileInput) {
  mediaFileInput.addEventListener('change', (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    const url = URL.createObjectURL(file);
    const mediaEl = document.getElementById('sourceMedia');
    if (!mediaEl) return;
    mediaEl.src = url;
    mediaEl.play().catch(err => console.warn('Autoplay blocked; please press play on the media element', err));
  });
}

// Initialize device enumeration
enumerateDevices();

document.getElementById('start').addEventListener('click', async () => {
  const roomId = 'poc_room';
  const { rtpCapabilities } = await new Promise(resolve => socket.emit('joinRoom', { roomId }, resolve));
  device = new mediasoupClient.Device();
  await device.load({ routerRtpCapabilities: rtpCapabilities });

  const transportInfo = await new Promise(resolve => socket.emit('createTransport', { roomId }, resolve));
  sendTransport = device.createSendTransport({ id: transportInfo.id, iceParameters: transportInfo.iceParameters, iceCandidates: transportInfo.iceCandidates, dtlsParameters: transportInfo.dtlsParameters });

  sendTransport.on('connect', ({ dtlsParameters }, callback, errback) => {
    socket.emit('connectTransport', { transportId: transportInfo.id, dtlsParameters }, res => {
      if (res && res.error) return errback(res.error);
      callback();
    });
  });

  sendTransport.on('produce', ({ kind, rtpParameters }, callback, errback) => {
    console.log('produce event triggered:', { kind, transportId: transportInfo.id });
    socket.emit('produce', { transportId: transportInfo.id, kind, rtpParameters, roomId }, (res) => {
      if (res && res.error) {
        console.error('produce failed:', res.error);
        return errback(res.error);
      }
      console.log('producer created with id:', res.id);
      callback({ id: res.id });
    });
  });

  // Get audio stream based on selected source
  let userMediaStream;
  const source = document.querySelector('input[name="capture_source"]:checked').value;
  
  if (source === 'media') {
    // Try to capture from the media element
    const mediaEl = document.getElementById('sourceMedia');
    if (mediaEl && mediaEl.captureStream) {
      try {
        userMediaStream = mediaEl.captureStream();
        console.log('Using captureStream() from media element');
      } catch (err) {
        console.warn('captureStream failed, falling back to getUserMedia', err);
      }
    } else {
      console.warn('No captureStream available on this browser/media element; falling back to microphone');
    }
  }

  if (!userMediaStream) {
    // Fallback to microphone using modern API
    try {
      const selectedDeviceId = document.getElementById('input_device_selector').value;
      const config = { 
        audio: {
          deviceId: selectedDeviceId || 'default',
          autoGainControl: false,
          channelCount: { ideal: 2 },
          echoCancellation: false,
          noiseSuppression: false,
          sampleRate: 44100,
          sampleSize: 16,
          volume: 1.0
        },
        video: false
      };
      userMediaStream = await navigator.mediaDevices.getUserMedia(config);
      console.log('Using getUserMedia() from microphone');
    } catch (error) {
      console.error("Failed to get user media stream", error);
      alert("Failed to get audio stream: " + error.message);
      return;
    }
  }

  const track = userMediaStream.getAudioTracks()[0];
  if (!track) {
    console.error('No audio track found');
    alert('No audio track available');
    return;
  }

  const producer = await sendTransport.produce({ track });
  console.log('producing audio, producer id:', producer.id);
});
