-- TaskFlow initial schema
CREATE TABLE IF NOT EXISTS users (
    id         SERIAL PRIMARY KEY,
    email      TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS tasks (
    id         SERIAL PRIMARY KEY,
    user_id    INT REFERENCES users(id),
    title      TEXT NOT NULL,
    done       BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);
