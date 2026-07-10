-- This file is auto-generated from the FilesDB schema. To make changes,
-- update the configuration files in "migrations/tooling/config/schema/" and then run
-- `migrations/bin/disco schema generate` to regenerate this file.

CREATE TABLE downloads
(
    id                TEXT NOT NULL PRIMARY KEY,
    original_filename TEXT NOT NULL
);


CREATE TABLE optimized_images
(
    id         INTEGER  PRIMARY KEY,
    created_at DATETIME,
    etag       TEXT,
    extension  TEXT     NOT NULL,
    filesize   INTEGER,
    height     INTEGER  NOT NULL,
    sha1       TEXT     NOT NULL,
    upload_id  INTEGER  NOT NULL,
    url        TEXT     NOT NULL,
    version    INTEGER,
    width      INTEGER  NOT NULL
);


CREATE TABLE upload_results
(
    id           TEXT      NOT NULL PRIMARY KEY,
    markdown     TEXT,
    skip_details TEXT,
    skip_reason  ENUM_TEXT,
    status       ENUM_TEXT NOT NULL,
    upload_id    INTEGER
);


CREATE TABLE uploads
(
    id                           INTEGER  PRIMARY KEY,
    animated                     BOOLEAN,
    created_at                   DATETIME,
    dominant_color               TEXT,
    etag                         TEXT,
    extension                    TEXT,
    filesize                     INTEGER  NOT NULL,
    height                       INTEGER,
    origin                       TEXT,
    original_filename            TEXT     NOT NULL,
    original_sha1                TEXT,
    secure                       BOOLEAN,
    security_last_changed_at     DATETIME,
    security_last_changed_reason TEXT,
    sha1                         TEXT,
    thumbnail_height             INTEGER,
    thumbnail_width              INTEGER,
    url                          TEXT     NOT NULL,
    verification_status          INTEGER,
    width                        INTEGER
);


