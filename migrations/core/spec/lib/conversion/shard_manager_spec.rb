# frozen_string_literal: true

require "extralite"

RSpec.describe Migrations::Conversion::ShardManager do
  around do |example|
    Dir.mktmpdir do |dir|
      @canonical = File.join(dir, "intermediate.db")
      @migrations = File.join(dir, "migrations")
      FileUtils.mkdir_p(@migrations)
      File.write(File.join(@migrations, "001-schema.sql"), <<~SQL)
        CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT);
        CREATE INDEX widgets_name ON widgets (name);
      SQL
      Migrations::Database.migrate(@canonical, migrations_path: @migrations)

      # a row from a previous run already lives in the DB
      db = Extralite::Database.new(@canonical)
      db.execute("INSERT INTO widgets (id, name) VALUES (1, 'existing')")
      db.close

      example.run
    end
  end

  def build_manager
    described_class.new(canonical_path: @canonical, migrations_path: @migrations)
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
