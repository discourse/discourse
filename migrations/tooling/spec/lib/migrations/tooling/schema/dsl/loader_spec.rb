# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::Loader do
  let(:fixtures_path) { File.join(__dir__, "..", "..", "..", "..", "..", "fixtures", "schema") }

  after { Migrations::Tooling::Schema.reset! }

  describe "#load!" do
    it "loads all config files from the fixture directory" do
      described_class.new(fixtures_path).load!

      config = Migrations::Tooling::Schema.config
      expect(config).to be_a(Migrations::Tooling::Schema::DSL::Configuration)
      expect(config.output_config.schema_file).to eq("db/test_schema/100-base-schema.sql")

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions).to be_a(Migrations::Tooling::Schema::DSL::ConventionsConfig)
      expect(conventions.effective_name("id")).to eq("original_id")

      ignored = Migrations::Tooling::Schema.ignored_tables
      expect(ignored.table_names).to include("schema_migrations")

      enums = Migrations::Tooling::Schema.enums
      expect(enums["visibility"]).to be_a(Migrations::Tooling::Schema::DSL::EnumDef)
      expect(enums["visibility"].values["public"]).to eq(0)

      tables = Migrations::Tooling::Schema.tables
      expect(tables["users"]).to be_a(Migrations::Tooling::Schema::DSL::TableDef)
      expect(tables["users"].primary_key_columns).to eq(%w[id])
    end

    it "raises when config directory does not exist" do
      expect { described_class.new("/nonexistent/path").load! }.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Schema config directory not found: /nonexistent/path",
      )
    end

    it "raises when config.rb is missing" do
      Dir.mktmpdir do |dir|
        expect { described_class.new(dir).load! }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          /config\.rb/,
        )
      end
    end

    it "works without optional files" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
            Migrations::Tooling::Schema.configure do
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

        expect(Migrations::Tooling::Schema.config).not_to be_nil
        expect(Migrations::Tooling::Schema.conventions_config).to be_nil
        expect(Migrations::Tooling::Schema.ignored_tables).to be_nil
      end
    end

    it "wraps errors raised while loading a file in a ConfigError" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, "config.rb")
        File.write(config_path, "raise 'boom'\n")

        expect { described_class.new(dir).load! }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "Error loading #{config_path}: boom",
        )
      end
    end

    it "lets a ConfigError raised while loading a file propagate unwrapped" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
            raise Migrations::Tooling::Schema::ConfigError, "boom from config"
          RUBY

        expect { described_class.new(dir).load! }.to raise_error(
          Migrations::Tooling::Schema::ConfigError,
          "boom from config",
        )
      end
    end

    it "loads enum files in sorted order" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), "")
        enums_dir = File.join(dir, "enums")
        Dir.mkdir(enums_dir)
        a = File.join(enums_dir, "a.rb")
        b = File.join(enums_dir, "b.rb")
        File.write(a, "")
        File.write(b, "")

        allow(Dir).to receive(:[]).and_call_original
        allow(Dir).to receive(:[]).with(File.join(enums_dir, "*.rb")).and_return([b, a])

        loaded = []
        allow(Kernel).to receive(:load) { |path| loaded << path }

        described_class.new(dir).load!

        expect(loaded).to eq([File.join(dir, "config.rb"), a, b])
      end
    end

    it "loads table files in sorted order" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), "")
        tables_dir = File.join(dir, "tables")
        Dir.mkdir(tables_dir)
        a = File.join(tables_dir, "a.rb")
        b = File.join(tables_dir, "b.rb")
        File.write(a, "")
        File.write(b, "")

        allow(Dir).to receive(:[]).and_call_original
        allow(Dir).to receive(:[]).with(File.join(tables_dir, "*.rb")).and_return([b, a])

        loaded = []
        allow(Kernel).to receive(:load) { |path| loaded << path }

        described_class.new(dir).load!

        expect(loaded).to eq([File.join(dir, "config.rb"), a, b])
      end
    end
  end
end
