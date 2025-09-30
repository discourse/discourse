CREATE TABLE site_settings
(
  name   TEXT      NOT NULL PRIMARY KEY,
  value  TEXT,
  action ENUM_TEXT
);
