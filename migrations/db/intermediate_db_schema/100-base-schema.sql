/*
 This file is auto-generated from the Discourse core database schema. Instead of editing it directly,
 please update the `schema.yml` configuration file and re-run the `generate_schema` script to update it.
*/

CREATE TABLE users
(
    id                        INTEGER  NOT NULL PRIMARY KEY,
    active                    BOOLEAN  NOT NULL,
    admin                     BOOLEAN  NOT NULL,
    approved                  BOOLEAN  NOT NULL,
    created_at                DATETIME NOT NULL,
    staged                    BOOLEAN  NOT NULL,
    trust_level               INTEGER  NOT NULL,
    username                  TEXT     NOT NULL,
    views                     INTEGER  NOT NULL,
    approved_at               DATETIME,
    approved_by_id            INTEGER,
    date_of_birth             DATE,
    first_seen_at             DATETIME,
    flair_group_id            INTEGER,
    group_locked_trust_level  INTEGER,
    ip_address                TEXT,
    last_seen_at              DATETIME,
    locale                    TEXT,
    manual_locked_trust_level INTEGER,
    moderator                 BOOLEAN,
    name                      TEXT,
    previous_visit_at         DATETIME,
    primary_group_id          INTEGER,
    registration_ip_address   TEXT,
    silenced_till             DATETIME,
    suspended_at              DATETIME,
    suspended_till            DATETIME,
    title                     TEXT,
    uploaded_avatar_id        TEXT
);
