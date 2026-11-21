CREATE TABLE metadata (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);

CREATE TABLE entries (
  kind TEXT NOT NULL,
  original_id TEXT NOT NULL,
  source_hash TEXT NOT NULL,
  payload TEXT NOT NULL,
  PRIMARY KEY (kind, original_id, source_hash)
);
