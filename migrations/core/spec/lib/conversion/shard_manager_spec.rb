# frozen_string_literal: true

require "extralite"

RSpec.describe Migrations::Conversion::ShardManager do
  let(:shard_context) { {} }

  around do |example|
    Dir.mktmpdir do |dir|
      shard_context[:canonical_path] = File.join(dir, "intermediate.db")
      shard_context[:migrations_path] = File.join(dir, "migrations")
      FileUtils.mkdir_p(shard_context[:migrations_path])
      File.write(File.join(shard_context[:migrations_path], "001-schema.sql"), <<~SQL)
        CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);
        CREATE INDEX widgets_name ON widgets (name);
      SQL
      Migrations::Database.migrate(
        shard_context[:canonical_path],
        migrations_path: shard_context[:migrations_path],
      )

      # a row from a previous run already lives in the DB
      db = Extralite::Database.new(shard_context[:canonical_path])
      db.execute("INSERT INTO widgets (id, name) VALUES (1, 'existing')")
      db.close

      example.run
    end
  end

  def build_manager
    described_class.new(
      canonical_path: shard_context.fetch(:canonical_path),
      migrations_path: shard_context.fetch(:migrations_path),
    )
  end

  it "gives each shard the run's schema but none of its data" do
    manager = build_manager
    db = Extralite::Database.new(manager.create_shard)

    tables =
      db.query_array(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      ).flatten
    indexes = db.query_array("SELECT name FROM sqlite_master WHERE type = 'index'").flatten

    expect(tables).to include("widgets") # schema is there
    expect(indexes).to include("widgets_name") # indexes too
    expect(db.query_single_splat("SELECT COUNT(*) FROM widgets")).to eq(0) # but no rows
  ensure
    db&.close
    manager&.cleanup
  end

  it "hands out a distinct shard path each time" do
    manager = build_manager
    expect(manager.create_shard).not_to eq(manager.create_shard)
  ensure
    manager&.cleanup
  end
end
