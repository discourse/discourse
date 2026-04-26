# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Loader do
  let(:fixtures_path) { File.join(__dir__, "..", "..", "..", "..", "fixtures", "schema") }

  after { Migrations::Database::Schema.reset! }

  describe "#load!" do
    it "loads all config files from the fixture directory" do
      described_class.new(fixtures_path).load!

      config = Migrations::Database::Schema.config
      expect(config).to be_a(Migrations::Database::Schema::DSL::Configuration)
      expect(config.output_config.schema_file).to eq("db/test_schema/100-base-schema.sql")

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions).to be_a(Migrations::Database::Schema::DSL::ConventionsConfig)
      expect(conventions.effective_name("id")).to eq("original_id")

      ignored = Migrations::Database::Schema.ignored_tables
      expect(ignored.table_names).to include("schema_migrations")

      enums = Migrations::Database::Schema.enums
      expect(enums["visibility"]).to be_a(Migrations::Database::Schema::DSL::EnumDef)
      expect(enums["visibility"].values["public"]).to eq(0)

      tables = Migrations::Database::Schema.tables
      expect(tables["users"]).to be_a(Migrations::Database::Schema::DSL::TableDef)
      expect(tables["users"].primary_key_columns).to eq(%w[id])
    end

    it "raises when config directory does not exist" do
      expect { described_class.new("/nonexistent/path").load! }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /not found/,
      )
    end

    it "raises when config.rb is missing" do
      Dir.mktmpdir do |dir|
        expect { described_class.new(dir).load! }.to raise_error(
          Migrations::Database::Schema::ConfigError,
          /config\.rb/,
        )
      end
    end

    it "works without optional files" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
            Migrations::Database::Schema.configure do
              output do
                schema_file "db/schema.sql"
                models_directory "lib/models"
                models_namespace "Test::Models"
                enums_directory "lib/enums"
                enums_namespace "Test::Enums"
              end
            end
          RUBY

        described_class.new(dir).load!

        expect(Migrations::Database::Schema.config).not_to be_nil
        expect(Migrations::Database::Schema.conventions_config).to be_nil
        expect(Migrations::Database::Schema.ignored_tables).to be_nil
      end
    end
  end
end
