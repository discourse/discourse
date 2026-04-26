# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema do
  after { described_class.reset! }

  describe ".validate" do
    it "includes resolved schema validation errors" do
      resolved =
        Migrations::Database::Schema::Definition.new(
          tables: [
            Migrations::Database::Schema::TableDefinition.new(
              name: "users",
              columns: [],
              indexes: [],
              primary_key_column_names: ["missing_id"],
              constraints: [],
              model_mode: nil,
            ),
          ],
          enums: [],
        )
      allow(described_class).to receive(:preflight).with(database: :test_db).and_return(
        described_class::PreflightResult.new(
          resolved:,
          errors: ["Table 'users': primary key references missing columns: missing_id"],
        ),
      )

      errors = described_class.validate(database: :test_db)

      expect(errors).to include(match(/primary key references missing columns: missing_id/))
    end

    it "returns static validation errors without attempting resolution" do
      allow(described_class).to receive(:preflight).with(database: :test_db).and_return(
        described_class::PreflightResult.new(resolved: nil, errors: ["Table 'users': bad config"]),
      )

      errors = described_class.validate(database: :test_db)

      expect(errors).to eq(["Table 'users': bad config"])
    end

    it "runs static validation before resolution in preflight" do
      validator =
        instance_double(
          Migrations::Database::Schema::DSL::Validator,
          validate: ["Table 'users': bad config"],
        )

      allow(described_class).to receive(:ensure_ready!).with(database: :test_db)
      allow(Migrations::Database::Schema::DSL::Validator).to receive(:new).with(
        described_class,
      ).and_return(validator)
      allow(Migrations::Database::Schema::DSL::SchemaResolver).to receive(:new)

      result = described_class.preflight(database: :test_db)

      expect(result.errors).to eq(["Table 'users': bad config"])
      expect(Migrations::Database::Schema::DSL::SchemaResolver).not_to have_received(:new)
    end
  end

  describe ".ignore_table" do
    let(:editor) do
      instance_double(Migrations::Database::Schema::DSL::IgnoredFileEditor, add_table: nil)
    end

    it "adds the table to ignored.rb after validating it" do
      connection =
        instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter, tables: %w[users])

      allow(described_class).to receive(:ensure_ready!).with(database: :test_db)
      allow(described_class).to receive(:find_table).with("users").and_return(nil)
      allow(described_class).to receive(:config_path).with(:test_db).and_return("/tmp/schema")
      allow(Migrations::Database::Schema::DSL::IgnoredFileEditor).to receive(:new).with(
        "/tmp/schema",
      ).and_return(editor)
      allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)

      described_class.ignore_table("users", reason: "legacy", database: :test_db)

      expect(editor).to have_received(:add_table).with("users", reason: "legacy")
    end

    it "rejects ignoring a table that is already configured" do
      allow(described_class).to receive(:ensure_ready!).with(database: :test_db)
      allow(described_class).to receive(:find_table).with("users").and_return(double)

      expect { described_class.ignore_table("users", database: :test_db) }.to raise_error(
        described_class::ConfigError,
        /already configured/,
      )
    end

    it "rejects ignoring a table that does not exist in the database" do
      connection =
        instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter, tables: %w[posts])

      allow(described_class).to receive(:ensure_ready!).with(database: :test_db)
      allow(described_class).to receive(:find_table).with("users").and_return(nil)
      allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)

      expect { described_class.ignore_table("users", database: :test_db) }.to raise_error(
        described_class::ConfigError,
        /does not exist in the database/,
      )
    end
  end

  describe ".ensure_ready!" do
    def write_minimal_config(tmpdir)
      config_dir = File.join(tmpdir, "config", "schema", "test_db")
      tables_dir = File.join(config_dir, "tables")
      FileUtils.mkdir_p(tables_dir)

      File.write(File.join(config_dir, "config.rb"), <<~RUBY)
          Migrations::Database::Schema.configure do
            output do
              schema_file "db/schema.sql"
              models_directory "lib/models"
              models_namespace "Migrations::Database::IntermediateDB"
              enums_directory "lib/enums"
              enums_namespace "Migrations::Database::IntermediateDB::Enums"
            end
          end
        RUBY

      File.write(File.join(tables_dir, "users.rb"), <<~RUBY)
          Migrations::Database::Schema.table :users do
            include_all
          end
        RUBY

      { config_dir:, tables_dir: }
    end

    it "resets partially loaded DSL state when loading fails" do
      Dir.mktmpdir do |tmpdir|
        paths = write_minimal_config(tmpdir)
        tables_dir = paths[:tables_dir]

        File.write(File.join(tables_dir, "broken.rb"), "raise 'boom'\n")

        manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest, fresh?: true)
        allow(described_class).to receive(:plugin_manifest).and_return(manifest)
        allow(Migrations).to receive(:root_path).and_return(tmpdir)

        expect { described_class.ensure_ready!(database: :test_db) }.to raise_error(
          described_class::ConfigError,
          /Error loading/,
        )

        File.write(File.join(tables_dir, "broken.rb"), <<~RUBY)
            Migrations::Database::Schema.table :posts do
              include_all
            end
          RUBY

        expect { described_class.ensure_ready!(database: :test_db) }.not_to raise_error
        expect(described_class.tables.keys).to contain_exactly("posts", "users")
      end
    end

    it "does not auto-regenerate when checksums are fresh but manifest is incomplete" do
      Dir.mktmpdir do |tmpdir|
        write_minimal_config(tmpdir)

        manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest, fresh?: true)
        allow(manifest).to receive(:regenerate!)
        allow(described_class).to receive(:plugin_manifest).and_return(manifest)
        allow(Migrations).to receive(:root_path).and_return(tmpdir)

        expect { described_class.ensure_ready!(database: :test_db) }.not_to raise_error
        expect(manifest).not_to have_received(:regenerate!)
      end
    end

    it "raises when stale manifest regeneration fails" do
      Dir.mktmpdir do |tmpdir|
        write_minimal_config(tmpdir)

        manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest, fresh?: false)
        allow(manifest).to receive(:regenerate!).and_raise(StandardError, "boom")
        allow(described_class).to receive(:plugin_manifest).and_return(manifest)
        allow(Migrations).to receive(:root_path).and_return(tmpdir)
        allow($stdout).to receive(:write)

        expect { described_class.ensure_ready!(database: :test_db) }.to raise_error(
          described_class::ConfigError,
          /Skipped/,
        )
      end
    end
  end
end
