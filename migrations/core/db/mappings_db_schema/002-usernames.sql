CREATE TABLE usernames
(
  discourse_user_id  NUMERIC NOT NULL,
  original_username  TEXT    NOT NULL,
  discourse_username TEXT    NOT NULL,
  PRIMARY KEY (discourse_user_id)
);

CREATE INDEX usernames_original_username ON usernames (original_username);
