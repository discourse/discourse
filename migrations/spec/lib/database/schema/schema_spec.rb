# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema do
  after { described_class.reset! }

  describe ".ensure_ready!" do
    it "resets partially loaded DSL state when loading fails" do
      Dir.mktmpdir do |tmpdir|
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

        File.write(File.join(tables_dir, "broken.rb"), "raise 'boom'\n")

        manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest, fresh?: true)
        allow(described_class).to receive(:plugin_manifest).with(database: :test_db).and_return(
          manifest,
        )
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
        expect(described_class.tables.keys).to contain_exactly(:posts, :users)
      end
    end
  end
end
