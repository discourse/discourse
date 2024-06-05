# frozen_string_literal: true

RSpec.describe Migrations::IntermediateDB::Migrator do
  def migrate(migrations_directory: nil, storage_path: nil, ignore_errors: false)
    migrations_path =
      if migrations_directory
        File.join(Migrations.root_path, "spec", "fixtures", "schema", migrations_directory)
      else
        nil
      end

    temp_path = storage_path = Dir.mktmpdir if storage_path.nil?
    db_path = File.join(storage_path, "intermediate.db")

    begin
      described_class.migrate(db_path, migrations_path:)
    rescue StandardError
      raise unless ignore_errors
    end

    yield db_path, storage_path
  ensure
    FileUtils.remove_dir(temp_path, force: true) if temp_path
  end

  describe ".migrate" do
    it "works with the default schema" do
      migrate do |db_path, storage_path|
        expect(Dir.children(storage_path)).to contain_exactly("intermediate.db")

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

  describe ".reset!" do
    it "deletes all DB related files" do
      migrate(migrations_directory: "invalid", ignore_errors: true) do |db_path, storage_path|
        File.write(File.join(storage_path, "hello_world.txt"), "Hello World!")

        expect(Dir.children(storage_path)).to contain_exactly(
          "intermediate.db",
          "intermediate.db-shm",
          "intermediate.db-wal",
          "hello_world.txt",
        )

        described_class.reset!(db_path)
        expect(Dir.children(storage_path)).to contain_exactly("hello_world.txt")
      end
    end
  end
end
