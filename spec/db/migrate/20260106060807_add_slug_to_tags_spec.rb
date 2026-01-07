# frozen_string_literal: true

require Rails.root.join("db/migrate/20260106060807_add_slug_to_tags.rb")

describe AddSlugToTags do
  def reset_slug_column
    DB.exec("DROP INDEX IF EXISTS index_tags_on_lower_slug")
    DB.exec("DROP INDEX IF EXISTS index_tags_on_slug")
    DB.exec("ALTER TABLE tags ALTER COLUMN slug DROP NOT NULL")
    DB.exec("UPDATE tags SET slug = NULL")
  end

  it "generates slugs from tag names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('Hello World', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("hello-world")
  end

  it "uses id-tag format for numeric-only names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('123', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("#{tag_id}-tag")
  end

  it "removes apostrophes from names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('Ruby''s Best', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("rubys-best")
  end

  it "replaces special characters with dashes" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('hello@world!', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("hello-world")
  end

  it "replaces unicode characters with dashes" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('hello字world', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("hello-world")
  end

  it "uses id-tag format for unicode-only names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('字', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("#{tag_id}-tag")
  end

  it "resolves conflicts by setting newer tag slug to empty" do
    reset_slug_column
    tag1_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('test', NOW(), NOW()) RETURNING id",
      )[
        0
      ]
    tag2_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('Test!', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug1 = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag1_id)[0]
    slug2 = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag2_id)[0]
    expect(slug1).to eq("test")
    expect(slug2).to eq("")
  end

  it "handles special character only names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('@#\$%', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("#{tag_id}-tag")
  end

  it "handles empty/whitespace names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('   ', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("#{tag_id}-tag")
  end

  it "squeezes consecutive dashes and spaces" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('hello   world--test', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("hello-world-test")
  end

  it "trims leading and trailing dashes" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('--hello--', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("hello")
  end

  it "keeps alphanumeric mixed names" do
    reset_slug_column
    tag_id =
      DB.query_single(
        "INSERT INTO tags (name, created_at, updated_at) VALUES ('123abc', NOW(), NOW()) RETURNING id",
      )[
        0
      ]

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = ?", tag_id)[0]
    expect(slug).to eq("123abc")
  end

  it "handles batching correctly with high id tags" do
    reset_slug_column
    DB.exec(
      "INSERT INTO tags (id, name, created_at, updated_at) VALUES (50000, 'batch-test', NOW(), NOW())",
    )

    AddSlugToTags.new.up

    slug = DB.query_single("SELECT slug FROM tags WHERE id = 50000")[0]
    expect(slug).to eq("batch-test")
  end
end
