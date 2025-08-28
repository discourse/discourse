CREATE TABLE permalink_placeholders
(
    url         TEXT    NOT NULL,
    placeholder TEXT    NOT NULL,
    target_type TEXT    NOT NULL,
    target_id   NUMERIC NOT NULL,
    PRIMARY KEY (url, placeholder)
);
