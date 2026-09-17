# frozen_string_literal: true

require "tmpdir"

# The three databases an import step works on: the IntermediateDB, plus the
# mappings and uploads databases attached to it as `mapped` and `files`. Wired
# the same way `Migrations::Importer::Executor` wires them, so a step spec sees
# the schema names its SQL uses.
RSpec.shared_context "with importer databases" do
  let(:intermediate_db) { @intermediate_db }

  let(:mapping_type) { Migrations::Importer::MappingType }
  let(:enums) { Migrations::Database::IntermediateDB::Enums }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@intermediate_db)

      attach_database(dir, "mappings.db", Migrations::Database::MAPPINGS_DB_SCHEMA_PATH, "mapped")
      attach_database(dir, "uploads.db", Migrations::Database::UPLOADS_DB_SCHEMA_PATH, "files")

      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
      @intermediate_db&.close
    end
  end

  def attach_database(dir, filename, schema_path, alias_name)
    path = File.join(dir, filename)
    Migrations::Database.migrate(path, migrations_path: schema_path)
    @intermediate_db.execute("ATTACH DATABASE ? AS #{alias_name}", path)
  end

  def add_mapping(original_id, type, discourse_id)
    @intermediate_db.execute(
      "INSERT INTO mapped.ids (original_id, type, discourse_id) VALUES (?, ?, ?)",
      original_id,
      type,
      discourse_id,
    )
  end

  def add_upload_file(id, attributes, markdown: nil)
    @intermediate_db.execute(
      "INSERT INTO files.uploads (id, upload, markdown) VALUES (?, ?, ?)",
      id,
      attributes&.to_json,
      markdown,
    )
  end

  def post_numbers
    @intermediate_db
      .query("SELECT original_id, post_number FROM mapped.post_numbers")
      .to_h { |row| [row[:original_id], row[:post_number]] }
  end
end
