# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260715090355_copy_ai_post_image_descriptions_to_captions",
        )

describe CopyAiPostImageDescriptionsToCaptions do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { cleanup }

  after { cleanup }

  def cleanup
    connection.execute("DROP TABLE IF EXISTS ai_post_image_descriptions")
    connection.execute("DELETE FROM ai_post_image_captions WHERE post_id IN (123456, 123457)")
  end

  def create_legacy_table
    connection.execute("DROP TABLE IF EXISTS ai_post_image_descriptions")
    connection.execute <<~SQL
      CREATE TABLE ai_post_image_descriptions (
        id bigserial PRIMARY KEY,
        post_id integer NOT NULL,
        upload_id integer NOT NULL,
        base62_sha1 varchar(27) NOT NULL,
        locale varchar(20) NOT NULL,
        description text,
        attempts integer DEFAULT 0 NOT NULL,
        last_attempted_at timestamp(6) without time zone,
        last_error text,
        created_at timestamp(6) without time zone NOT NULL,
        updated_at timestamp(6) without time zone NOT NULL
      )
    SQL
  end

  def store_legacy_caption(post_id:, description:)
    connection.execute <<~SQL
      INSERT INTO ai_post_image_descriptions (
        post_id,
        upload_id,
        base62_sha1,
        locale,
        description,
        attempts,
        last_attempted_at,
        last_error,
        created_at,
        updated_at
      )
      VALUES (
        #{post_id},
        654321,
        'abc123',
        'en',
        #{connection.quote(description)},
        2,
        NOW(),
        'retry later',
        NOW(),
        NOW()
      )
    SQL
  end

  it "copies legacy image description rows to image captions", :aggregate_failures do
    create_legacy_table
    store_legacy_caption(post_id: 123_456, description: "legacy caption")

    migration.up

    row = DB.query(<<~SQL).first
        SELECT post_id, upload_id, base62_sha1, locale, description, attempts, last_error
        FROM ai_post_image_captions
        WHERE post_id = 123456
      SQL

    expect(row.post_id).to eq(123_456)
    expect(row.upload_id).to eq(654_321)
    expect(row.base62_sha1).to eq("abc123")
    expect(row.locale).to eq("en")
    expect(row.description).to eq("legacy caption")
    expect(row.attempts).to eq(2)
    expect(row.last_error).to eq("retry later")
  end

  it "keeps existing image caption rows when old and new rows conflict" do
    create_legacy_table
    store_legacy_caption(post_id: 123_457, description: "legacy caption")

    connection.execute <<~SQL
      INSERT INTO ai_post_image_captions (
        post_id,
        upload_id,
        base62_sha1,
        locale,
        description,
        attempts,
        created_at,
        updated_at
      )
      VALUES (123457, 654321, 'abc123', 'en', 'existing caption', 0, NOW(), NOW())
    SQL

    migration.up

    expect(
      DB.query_single(
        "SELECT description FROM ai_post_image_captions WHERE post_id = 123457",
      ).first,
    ).to eq("existing caption")
  end

  it "does not fail when the legacy table does not exist" do
    connection.execute("DROP TABLE IF EXISTS ai_post_image_descriptions")

    expect { migration.up }.not_to raise_error
  end
end
