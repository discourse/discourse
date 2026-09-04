# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Importer::PlaceholderLinkages do
  let(:embed_owner) { Migrations::Database::IntermediateDB::Enums::EmbedOwner }
  let(:link_target) { Migrations::Database::IntermediateDB::Enums::LinkTarget }

  it "resolves owner ids, coordinate pairs, and slugs within the configured bind limit" do
    4.times do |index|
      Migrations::Database::IntermediateDB::Topic.create(
        original_id: index + 10,
        title: "Topic #{index}",
        slug: "topic-#{index}",
      )
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: index + 1,
        placeholder: "link-#{index}",
        target_type: link_target::TOPIC,
        target_name: "topic-#{index}",
      )
    end

    intermediate_db.execute(<<~SQL)
      CREATE TABLE posts (
        original_id NUMERIC NOT NULL,
        topic_id NUMERIC NOT NULL,
        post_number INTEGER NOT NULL
      )
    SQL
    [[100, 20, 2], [101, 21, 3]].each do |original_id, topic_id, post_number|
      intermediate_db.execute(
        "INSERT INTO posts (original_id, topic_id, post_number) VALUES (?, ?, ?)",
        original_id,
        topic_id,
        post_number,
      )
    end
    [[5, 20, 2], [6, 21, 3]].each do |owner_id, topic_id, post_number|
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
        owner_id:,
        placeholder: "quote-#{owner_id}",
        quoted_topic_id: topic_id,
        quoted_post_number: post_number,
      )
    end

    real_db = intermediate_db
    limited_db = Object.new
    limited_db.define_singleton_method(:query) do |sql, *parameters, &block|
      raise "query exceeded bind limit" if parameters.size > 3

      real_db.query(sql, *parameters, &block)
    end
    linkages = described_class.new(limited_db, bind_limit: 3)

    resolved = linkages.load_and_resolve((1..6).to_a, owner_type: embed_owner::POST)

    links = resolved.values.flatten(1).filter_map { |kind, row| row if kind == :link }
    quotes = resolved.values.flatten(1).filter_map { |kind, row| row if kind == :quote }
    expect(links.map { |row| row[:target_id] }).to contain_exactly(10, 11, 12, 13)
    expect(quotes.map { |row| row[:quoted_post_id] }).to contain_exactly(100, 101)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@intermediate_db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  def intermediate_db
    @intermediate_db
  end
end
