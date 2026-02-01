DROP TABLE IF EXISTS room_participants CASCADE;
DROP TABLE IF EXISTS playlist CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- 1. Create 'profiles' table (Used by LoginScreen with custom UUIDs)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY, -- ID is generated client-side (Uuid().v4())
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL
);

-- 2. Create 'rooms' table
CREATE TABLE IF NOT EXISTS rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    name TEXT NOT NULL,
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    current_song_index BIGINT DEFAULT -1,
    is_playing BOOLEAN DEFAULT FALSE
);

-- 3. Create 'playlist' table
CREATE TABLE IF NOT EXISTS playlist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    video_id TEXT NOT NULL,
    song_order BIGINT NOT NULL,
    duration_ms BIGINT DEFAULT 0,
    added_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

-- 4. Create 'room_participants' table
CREATE TABLE IF NOT EXISTS room_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE
);

-- Enable Row Level Security (RLS) - Optional but recommended
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE playlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;

-- Create policies (Allow public access since auth is custom/anonymous)
CREATE POLICY "Enable read/write access for all users" ON profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable read/write access for all users" ON rooms FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable read/write access for all users" ON playlist FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable read/write access for all users" ON room_participants FOR ALL USING (true) WITH CHECK (true);
