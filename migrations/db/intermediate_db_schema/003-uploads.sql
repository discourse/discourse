CREATE TABLE uploads
(
    id          TEXT NOT NULL PRIMARY KEY,
    filename    TEXT NOT NULL,
    path        TEXT,
    data        BLOB,
    url         TEXT,
    type        TEXT,
    description TEXT,
    origin      TEXT,
    user_id     NUMERIC
);
