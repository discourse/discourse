CREATE TABLE uploads
(
    id BLOB PRIMARY KEY NOT NULL,
    upload JSON_TEXT,
    markdown TEXT,
    skip_reason TEXT
);

CREATE TABLE optimized_images
(
    id BLOB PRIMARY KEY NOT NULL,
    optimized_images JSON_TEXT
);

CREATE TABLE downloads (
    id BLOB PRIMARY KEY NOT NULL,
    original_filename TEXT NOT NULL
);
