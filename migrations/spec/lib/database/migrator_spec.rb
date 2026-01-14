# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Migrator do
  def migrate(
    migrations_directory: nil,
    migrations_path: nil,
    storage_path: nil,
    db_filename: "intermediate.db",
    ignore_errors: false
  )
    if migrations_directory
      migrations_path = File.join(fixture_root, "schema", migrations_directory)
    end

    temp_path = storage_path = Dir.mktmpdir if storage_path.nil?
    db_path = File.join(storage_path, db_filename)

    begin
      described_class.new(db_path).migrate(migrations_path)
    rescue StandardError
      raise unless ignore_errors
    end

    yield db_path, storage_path
  ensure
    FileUtils.remove_dir(temp_path, force: true) if temp_path
  end

  describe "#migrate" do
    it "works with the IntermediateDB schema" do
      migrate(
        migrations_path: ::Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
        db_filename: "intermediate.db",
      ) do |db_path, storage_path|
        expect(Dir.children(storage_path)).to contain_exactly("intermediate.db")

        db = Extralite::Database.new(db_path)
        expect(db.tables).not_to be_empty
        db.close
      end
    end

    it "works with the UploadsDB schema" do
      migrate(
        migrations_path: ::Migrations::Database::UPLOADS_DB_SCHEMA_PATH,
        db_filename: "uploads.db",
      ) do |db_path, storage_path|
        expect(Dir.children(storage_path)).to contain_exactly("uploads.db")

        db = Extralite::Database.new(db_path)
        expect(db.tables).not_to be_empty
        db.close
      end
    end

    it "executes schema files" do
      Dir.mktmpdir do |storage_path|
        migrate(migrations_directory: "one", storage_path:) do |db_path|
          db = Extralite::Database.new(db_path)
          expect(db.tables).to contain_exactly("first_table", "schema_migrations")
          db.close
        end

        migrate(migrations_directory: "one", storage_path:) do |db_path|
          db = Extralite::Database.new(db_path)
          expect(db.tables).to contain_exactly("first_table", "schema_migrations")
          db.close
        end

        migrate(migrations_directory: "two", storage_path:) do |db_path|
          db = Extralite::Database.new(db_path)
          expect(db.tables).to contain_exactly("first_table", "second_table", "schema_migrations")
          db.close
        end
      end
    end
  end

  describe "#reset!" do
    it "deletes all DB related files" do
      migrate(migrations_directory: "invalid", ignore_errors: true) do |db_path, storage_path|
        File.write(File.join(storage_path, "hello_world.txt"), "Hello World!")

        expect(Dir.children(storage_path)).to contain_exactly(
          "intermediate.db",
          "intermediate.db-shm",
          "intermediate.db-wal",
          "hello_world.txt",
        )

        described_class.new(db_path).reset!
        expect(Dir.children(storage_path)).to contain_exactly("hello_world.txt")
      end
    end
  end
end
