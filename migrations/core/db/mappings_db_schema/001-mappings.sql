CREATE TABLE ids
(
  original_id  NUMERIC NOT NULL,
  type         INTEGER NOT NULL,
  discourse_id NUMERIC NOT NULL,
  PRIMARY KEY (original_id, type)
);
