CREATE TABLE ids
(
  original_id  NUMERIC NOT NULL,
  type         INTEGER NOT NULL,
  discourse_id NUMERIC NOT NULL,
  PRIMARY KEY (original_id, type)
);

CREATE TABLE posts
(
  original_id  NUMERIC NOT NULL PRIMARY KEY,
  discourse_id NUMERIC NOT NULL,
  topic_id     NUMERIC NOT NULL,
  post_number  INTEGER NOT NULL
);

CREATE INDEX index_posts_on_topic_id_and_post_number ON posts (topic_id, post_number);
