CREATE TABLE log_entries
(
    created_at DATETIME NOT NULL,
    type       TEXT     NOT NULL,
    message    TEXT     NOT NULL,
    exception  TEXT,
    details    JSON_TEXT
);
