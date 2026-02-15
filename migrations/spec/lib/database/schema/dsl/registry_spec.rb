# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::Registry do
  subject(:registry) { described_class.new }

  let(:config) { Migrations::Database::Schema::DSL::Configuration.new(output_config: nil) }
  let(:conventions) do
    Migrations::Database::Schema::DSL::ConventionsConfig.new(conventions: [], ignored_columns: [])
  end
  let(:table_def) { Migrations::Database::Schema::DSL::TableBuilder.new(:users).build }
  let(:enum_def) do
    builder = Migrations::Database::Schema::DSL::EnumBuilder.new(:status)
    builder.value(:active, 0)
    builder.build
  end
  let(:ignored) { Migrations::Database::Schema::DSL::IgnoredConfig.new(entries: []) }

  describe "#register_config" do
    it "stores configuration" do
      registry.register_config(config)
      expect(registry.config).to eq(config)
    end

    it "raises on duplicate registration" do
      registry.register_config(config)
      expect { registry.register_config(config) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end

  describe "#register_conventions" do
    it "stores conventions" do
      registry.register_conventions(conventions)
      expect(registry.conventions_config).to eq(conventions)
    end

    it "raises on duplicate registration" do
      registry.register_conventions(conventions)
      expect { registry.register_conventions(conventions) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end

  describe "#register_table" do
    it "stores a table definition" do
      registry.register_table(:users, table_def)
      expect(registry.table(:users)).to eq(table_def)
    end

    it "raises on duplicate table name" do
      registry.register_table(:users, table_def)
      expect { registry.register_table(:users, table_def) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end

  describe "#register_enum" do
    it "stores an enum definition" do
      registry.register_enum(:status, enum_def)
      expect(registry.enum(:status)).to eq(enum_def)
    end

    it "raises on duplicate enum name" do
      registry.register_enum(:status, enum_def)
      expect { registry.register_enum(:status, enum_def) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end

  describe "#register_ignored" do
    it "stores ignored table config" do
      registry.register_ignored(ignored)
      expect(registry.ignored_tables).to eq(ignored)
    end

    it "raises on duplicate registration" do
      registry.register_ignored(ignored)
      expect { registry.register_ignored(ignored) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /already registered/,
      )
    end
  end

  describe "#tables and #enums" do
    it "returns frozen duplicates" do
      registry.register_table(:users, table_def)
      registry.register_enum(:status, enum_def)

      tables = registry.tables
      enums = registry.enums

      expect(tables).to eq({ users: table_def })
      expect(enums).to eq({ status: enum_def })
      expect(tables).to be_frozen
      expect(enums).to be_frozen
    end
  end

  describe "#freeze!" do
    it "prevents further registration" do
      registry.freeze!
      expect(registry).to be_frozen
      expect { registry.register_config(config) }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /frozen/,
      )
    end
  end
end
