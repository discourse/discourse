CREATE TABLE tag_synonyms
(
    synonym_tag_id NUMERIC NOT NULL PRIMARY KEY,
    target_tag_id  NUMERIC NOT NULL
);
