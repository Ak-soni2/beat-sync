-- Run this to enable the 'Finalize Playlist' feature

-- 1. Create 'saved_playlists' table (for saving room queues)
CREATE TABLE IF NOT EXISTS saved_playlists (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    name TEXT NOT NULL,
    owner_id UUID REFERENCES profiles(id)
);

-- 2. Create 'saved_playlist_songs' table
CREATE TABLE IF NOT EXISTS saved_playlist_songs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    playlist_id UUID NOT NULL REFERENCES saved_playlists(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL,
    title TEXT NOT NULL,
    duration_ms BIGINT DEFAULT 0,
    song_order BIGINT NOT NULL
);

-- Enable RLS
ALTER TABLE saved_playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_playlist_songs ENABLE ROW LEVEL SECURITY;

-- Policies (Open for now)
CREATE POLICY "Enable read/write for all" ON saved_playlists FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable read/write for all" ON saved_playlist_songs FOR ALL USING (true) WITH CHECK (true);
