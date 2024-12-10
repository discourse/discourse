-- This file is auto-generated from the IntermediateDB schema. To make changes, update
-- the "config/intermediate_db.yml" configuration file and then run `cli schema generate` to
-- regenerate this file.

CREATE TABLE users
(
    id                        NUMERIC  NOT NULL PRIMARY KEY,
    active                    BOOLEAN,
    admin                     BOOLEAN,
    approved                  BOOLEAN,
    approved_at               DATETIME,
    approved_by_id            NUMERIC,
    created_at                DATETIME NOT NULL,
    date_of_birth             DATE,
    first_seen_at             DATETIME,
    flair_group_id            NUMERIC,
    group_locked_trust_level  INTEGER,
    ip_address                INET_TEXT,
    last_seen_at              DATETIME,
    locale                    TEXT,
    manual_locked_trust_level INTEGER,
    moderator                 BOOLEAN,
    name                      TEXT,
    previous_visit_at         DATETIME,
    primary_group_id          NUMERIC,
    registration_ip_address   INET_TEXT,
    required_fields_version   INTEGER,
    silenced_till             DATETIME,
    staged                    BOOLEAN,
    suspended_at              DATETIME,
    suspended_till            DATETIME,
    title                     TEXT,
    trust_level               INTEGER  NOT NULL,
    uploaded_avatar_id        TEXT,
    username                  TEXT     NOT NULL,
    views                     INTEGER
);

