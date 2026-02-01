-- Update Schema for Smart-Cache Sync

-- 1. Update 'rooms' table
-- status: 'open', 'preparing', 'ready', 'playing'
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open';
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS start_timestamp BIGINT DEFAULT 0;

-- 2. Update 'room_participants' table
ALTER TABLE room_participants ADD COLUMN IF NOT EXISTS is_ready BOOLEAN DEFAULT FALSE;

-- 3. Reset policies just in case (optional)
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;
