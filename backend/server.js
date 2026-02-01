require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const ytSearch = require('yt-search');
const { createClient } = require('@supabase/supabase-js');

// --- Configuration ---
const ytdl = require('@distube/ytdl-core'); // Import the new library (Added)

// ... Configuration ...
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Allow all origins (Flutter app)
        methods: ["GET", "POST"]
    }
});

// Middleware
app.use(cors());
app.use(express.json());

// Database (Supabase)
const supabaseUrl = process.env.SUPABASE_URL || 'YOUR_SUPABASE_URL';
const supabaseKey = process.env.SUPABASE_KEY || 'YOUR_SERVICE_ROLE_KEY';
const supabase = createClient(supabaseUrl, supabaseKey);

// --- API Endpoints ---

// NEW ENDPOINT: Get Playable URL
app.get('/get-audio-url', async (req, res) => {
    try {
        const videoId = req.query.videoId;
        if (!videoId) return res.status(400).json({ error: "No videoId" });

        const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;

        // 1. Get Info
        const info = await ytdl.getInfo(videoUrl);

        // 2. Choose best audio format (m4a/mp3)
        const format = ytdl.chooseFormat(info.formats, {
            quality: 'highestaudio',
            filter: 'audioonly'
        });

        if (!format || !format.url) {
            return res.status(404).json({ error: "No audio found" });
        }

        // 3. Return the direct GoogleVideo URL
        res.json({ url: format.url });

    } catch (e) {
        console.error(e);
        res.status(500).json({ error: e.message });
    }
});

/**
 * SEARCH API
 * GET /search?q=query
 * Returns: [{ id, title, thumbnail, duration_ms }]
 */
app.get('/search', async (req, res) => {
    try {
        const query = req.query.q;
        if (!query) return res.status(400).json({ error: 'Missing query' });

        console.log(`🔍 Searching for: ${query}`);
        const r = await ytSearch(query);

        // Transform results to match our schema
        const songs = r.videos.slice(0, 10).map(v => ({
            id: v.videoId,
            title: v.title,
            thumbnail: v.thumbnail,
            duration_ms: v.seconds * 1000
        }));

        res.json(songs);
    } catch (e) {
        console.error("Search Error:", e);
        res.status(500).json({ error: e.message });
    }
});

// --- Socket.io Logic (Sync Coordinator) ---

io.on('connection', (socket) => {
    console.log(`🔌 User Connected: ${socket.id}`);

    // 1. Join Room
    socket.on('join_room', (roomCode) => {
        socket.join(roomCode);
        console.log(`👤 ${socket.id} joined room: ${roomCode}`);
    });

    // 2. State Update (Host broadcasting changes)
    // Payload: { roomCode, isPlaying, songIndex, currentPosition }
    socket.on('update_state', async (payload) => {
        const { roomCode, isPlaying, songIndex } = payload;

        // Broadcast to everyone else in the room IMMEDIATELY for speed
        socket.to(roomCode).emit('state_changed', payload);

        // Persist to Supabase (Optional for persistence, mainly for late joiners)
        // We update this asynchronously so we don't block the socket broadcast
        try {
            await supabase
                .from('rooms')
                .update({
                    is_playing: isPlaying,
                    current_song_index: songIndex,
                    // start_timestamp: Date.now() - currentPosition // If you want perfect server-time sync
                })
                .eq('room_code', roomCode);
        } catch (e) {
            console.error("Supabase Update Error:", e);
        }
    });

    socket.on('disconnect', () => {
        console.log('❌ User Disconnected', socket.id);
    });
});

// --- Start Server ---
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`👉 Search: http://localhost:${PORT}/search?q=test`);
});
