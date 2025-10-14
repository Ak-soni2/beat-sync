var serverName = "Party_Not_PaTI_Server";
var peerConfig =  {
	host: "/",
	port: 9000,
	debug: 2
};
//serverName = null;
//peerConfig = null;

function repopulateConnections() {
	let list = $("#connections_list");
	list.empty();
	for(let connection of Object.keys(peer.connections)) {
		list.append($(`<ul>${connection}</ul>`));
	}
}

async function enumerateDevices() {
	let allDevices = await navigator.mediaDevices.enumerateDevices();
	let deviceIndex = 0;
	for(let device of allDevices) {
		switch(device.kind) {
			case 'audioinput':
				$("<option />")
				.attr('value', device.deviceId)
				.text(device.label || `Input #${deviceIndex}`)
				.appendTo("#input_device_selector");
			    deviceIndex++;
			break;
		}
	}
	$("#recordButton").show();
}
$("#recordButton").hide();
enumerateDevices();

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

$("#recordButton").click(async () => {
	$("#recordButton").hide();
	var userMediaStream;
	let config = { 
		audio : {
			deviceId: $("#input_device_selector option:selected").val(),
			autoGainControl: false,
			channelCount: { ideal: 2},
			echoCancellation: false,
			noiseSuppression: false,
			sampleRate: 44100,
			sampleSize: 16,
			volume: 1.0
		  },
		video : false
	};
	// Decide capture source: microphone or media element
	const source = document.querySelector('input[name="capture_source"]:checked').value;
	if (source === 'media') {
	    // try to capture from the media element
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
		// fallback to microphone using modern API
		try {
			userMediaStream = await navigator.mediaDevices.getUserMedia(config);
			window.userMediaStream = userMediaStream;
		} catch (error) {
			console.error("Failed to get user media stream", error);
			// restore UI so user can try again
			$("#recordButton").show();
			return;
		}
	} else {
		window.userMediaStream = userMediaStream;
	}

	var peer = new Peer(serverName, peerConfig);
	peer.on('error', (error) => {
		console.error("Peer error :");
		console.error(error);
	});
	peer.on('open', (id) => {
		console.log("Peer : Opened with ID : " + id);
		$("#peer_ID").text(id);
	});
	peer.on('connection', (connection) => {
		console.log("Peer : Incoming connection:");
		console.log(connection);

		// call client on connection
		call = peer.call(connection.peer, userMediaStream);
		call.on('stream', function(stream) {
			console.log("Call : Stream");
			console.log(stream);
		});
		call.on('close', function() {
			console.log("Call : Close");
		});
		call.on('error', function(error) {
			console.error("Call Error :");
			console.error(error);
		});
		window.call = call;

		repopulateConnections();
	});

	peer.on('call', (call) => {
		console.log("Peer : Incoming call:");
		console.log(call);
	});
	peer.on('disconnected', () => {
		console.log("Peer : Disconnected");
		repopulateConnections();
	});

	// legacy answer-calls block removed; callers are handled above if needed

	window.peer = peer;
});
