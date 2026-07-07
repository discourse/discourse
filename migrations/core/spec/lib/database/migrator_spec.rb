# frozen_string_literal: true

RSpec.describe Migrations::Database::Migrator do
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

  describe "#initialize" do
    it "expands a relative database path against Migrations.root_path" do
      allow(Migrations).to receive(:root_path).and_return("/base/migrations-root")

      migrator = described_class.new("subdir/data.db")

      expect(migrator.instance_variable_get(:@db_path)).to eq(
        "/base/migrations-root/subdir/data.db",
      )
    end
  end

  describe "#migrate" do
    it "works with the IntermediateDB schema" do
      migrate(
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
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
        migrations_path: Migrations::Database::UPLOADS_DB_SCHEMA_PATH,
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

    it "returns nil" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "intermediate.db")
        migrations_path = File.join(fixture_root, "schema", "one")

        result = described_class.new(db_path).migrate(migrations_path)

        expect(result).to be_nil
      end
    end

    it "stores the SHA1 hash of each migration's SQL" do
      migrations_path = File.join(fixture_root, "schema", "one")

      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "intermediate.db")
        described_class.new(db_path).migrate(migrations_path)

        db = Extralite::Database.new(db_path)
        stored_hashes = db.query_splat("SELECT sql_hash FROM schema_migrations")
        db.close

        sql = File.read(File.join(migrations_path, "001-first-table.sql"))
        expect(stored_hashes).to eq([Digest::SHA1.hexdigest(sql)])
      end
    end

    it "runs migrations in sorted order" do
      Dir.mktmpdir do |migrations_path|
        first = File.join(migrations_path, "001-create.sql")
        second = File.join(migrations_path, "002-insert.sql")
        File.write(first, "CREATE TABLE items (id INTEGER);")
        File.write(second, "INSERT INTO items (id) VALUES (1);")

        # Return the files in the wrong order: the inserting migration must only
        # run after the table exists, so the migrator has to sort them.
        allow(Dir).to receive(:[]).and_call_original
        allow(Dir).to receive(:[]).with(File.join(migrations_path, "*.sql")).and_return(
          [second, first],
        )

        Dir.mktmpdir do |storage_path|
          db_path = File.join(storage_path, "intermediate.db")
          described_class.new(db_path).migrate(migrations_path)

          db = Extralite::Database.new(db_path)
          expect(db.query_splat("SELECT id FROM items")).to eq([1])
          db.close
        end
      end
    end

    it "runs each migration in a transaction so a failing one is rolled back" do
      Dir.mktmpdir do |migrations_path|
        # The second statement fails because the table already exists; the whole
        # migration must roll back, leaving no trace of the first statement.
        File.write(
          File.join(migrations_path, "001-broken.sql"),
          "CREATE TABLE half_applied (id INTEGER);\nCREATE TABLE half_applied (id INTEGER);",
        )

        Dir.mktmpdir do |storage_path|
          db_path = File.join(storage_path, "intermediate.db")

          expect { described_class.new(db_path).migrate(migrations_path) }.to raise_error(
            Extralite::SQLError,
          )

          db = Extralite::Database.new(db_path)
          expect(db.tables).not_to include("half_applied")
          db.close
        end
      end
    end
  end
end
