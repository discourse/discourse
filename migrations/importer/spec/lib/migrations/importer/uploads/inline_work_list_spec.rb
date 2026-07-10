# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::InlineWorkList do
  # Runs against real migrated SQLite databases (intermediate + mappings), like
  # the optimizer/step smoke specs. No Rails needed — this is just SQL.
  let(:uploads_type) { Migrations::Importer::MappingType::UPLOADS }
  let(:users_type) { Migrations::Importer::MappingType::USERS }
  let(:system_user_id) { -1 }

  around do |example|
    Dir.mktmpdir do |dir|
      intermediate_path = File.join(dir, "intermediate.db")
      mappings_path = File.join(dir, "mappings.db")

      Migrations::Database.migrate(
        intermediate_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      Migrations::Database.migrate(
        mappings_path,
        migrations_path: Migrations::Database::MAPPINGS_DB_SCHEMA_PATH,
      )

      @db = Migrations::Database.connect(intermediate_path)
      @db.execute("ATTACH DATABASE ? AS mapped", mappings_path)
      example.run
    ensure
      @db&.close
    end
  end

  let(:db) { @db }

  def add_source(id:, user_id: nil)
    db.execute(
      "INSERT INTO upload_sources (id, filename, user_id, type) VALUES (?, ?, ?, ?)",
      id,
      "#{id}.png",
      user_id,
      uploads_type,
    )
  end

  def map_id(original_id:, type:, discourse_id:)
    db.execute(
      "INSERT INTO mapped.ids (original_id, type, discourse_id) VALUES (?, ?, ?)",
      original_id,
      type,
      discourse_id,
    )
  end

  it "counts only the sources without an uploads mapping yet" do
    add_source(id: "a")
    add_source(id: "b")
    map_id(original_id: "b", type: uploads_type, discourse_id: 999)

    expect(described_class.pending_count(db)).to eq(1)
  end

  it "returns the pending rows with the owning user resolved from the users map" do
    add_source(id: "a", user_id: "orig-7")
    map_id(original_id: "orig-7", type: users_type, discourse_id: 42)

    rows = described_class.rows(db, system_user_id:)

    expect(rows.map { |r| r[:id] }).to eq(["a"])
    expect(rows.first[:resolved_user_id]).to eq(42)
  end

  it "falls back to the system user when the source user is unmapped" do
    add_source(id: "a", user_id: "unmapped")

    rows = described_class.rows(db, system_user_id:)

    expect(rows.first[:resolved_user_id]).to eq(system_user_id)
  end

  it "excludes sources already mapped as uploads on a re-run" do
    add_source(id: "a")
    add_source(id: "b")
    map_id(original_id: "a", type: uploads_type, discourse_id: 100)

    rows = described_class.rows(db, system_user_id:)

    expect(rows.map { |r| r[:id] }).to eq(["b"])
  end
end
