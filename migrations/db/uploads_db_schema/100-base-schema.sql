CREATE TABLE uploads
(
    id TEXT PRIMARY KEY NOT NULL,
    upload JSON_TEXT,
    markdown TEXT,
    skip_reason TEXT
);

CREATE TABLE optimized_images
(
    id TEXT PRIMARY KEY NOT NULL,
    optimized_images JSON_TEXT
);
