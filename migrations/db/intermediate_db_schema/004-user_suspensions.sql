CREATE TABLE user_suspensions
(
  user_id         NUMERIC  NOT NULL,
  suspended_at    DATETIME NOT NULL,
  suspended_till  DATETIME,
  suspended_by_id NUMERIC,
  reason          TEXT,
  PRIMARY KEY (user_id, suspended_at)
);
