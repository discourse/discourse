CREATE TABLE uploads
(
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    placeholder_hash TEXT NOT NULL UNIQUE,
    filename         TEXT NOT NULL,
    path             TEXT,
    data             BLOB,
    url              TEXT,
    type             TEXT,
    description      TEXT,
    origin           TEXT,
    user_id          NUMERIC
);
