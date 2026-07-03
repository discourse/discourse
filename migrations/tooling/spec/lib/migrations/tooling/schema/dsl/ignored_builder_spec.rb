# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::IgnoredBuilder do
  after { Migrations::Tooling::Schema.reset! }

  describe "Schema.ignored" do
    it "registers ignored tables with reasons" do
      Migrations::Tooling::Schema.ignored do
        table :schema_migrations, "Rails internal table"
        table :ar_internal_metadata, "Rails internal table"
      end

      ignored = Migrations::Tooling::Schema.ignored_tables
      expect(ignored.table_names).to include("schema_migrations")
      expect(ignored.table_names).to include("ar_internal_metadata")
      expect(ignored.table_names).not_to include("users")
    end

    it "supports batch ignore with shared reason" do
      Migrations::Tooling::Schema.ignored { tables :temp_data, :old_logs, reason: "Legacy tables" }

      ignored = Migrations::Tooling::Schema.ignored_tables
      expect(ignored.table_names).to eq(Set["temp_data", "old_logs"])
      expect(ignored.reason_for(:temp_data)).to eq("Legacy tables")
      expect(ignored.reason_for(:old_logs)).to eq("Legacy tables")
    end
  end

  describe "plugin DSL" do
    it "raises when plugin reason is missing" do
      expect do Migrations::Tooling::Schema.ignored { plugin :chat, "" } end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /reason/,
      )
    end

    it "normalizes underscored plugin names to hyphenated names" do
      Migrations::Tooling::Schema.ignored { plugin :discourse_ai, "Not migrating" }

      ignored = Migrations::Tooling::Schema.ignored_tables
      expect(ignored.ignored_plugin_names).to eq(["discourse-ai"])
      expect(ignored.plugin_ignored?(:discourse_ai)).to be true
      expect(ignored.plugin_ignored?(:"discourse-ai")).to be true
    end
  end

  describe "#table" do
    subject(:builder) { described_class.new }

    it "records the table under its stringified name with the given reason" do
      builder.table(:users, "Handled elsewhere")

      entries = builder.build.entries
      expect(entries.size).to eq(1)
      expect(entries.first).to have_attributes(name: "users", reason: "Handled elsewhere")
    end

    it "defaults the reason to nil when it is omitted" do
      builder.table(:users)

      expect(builder.build.entries.first.reason).to be_nil
    end

    it "raises when the same table is declared twice" do
      builder.table(:users)

      expect { builder.table(:users) }.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Ignored table :users is already declared.",
      )
    end
  end

  describe "#tables" do
    subject(:builder) { described_class.new }

    it "records every name and flattens nested arrays" do
      builder.tables([:temp_data], :old_logs, reason: "Legacy")

      entries = builder.build.entries
      expect(entries.map(&:name)).to eq(%w[temp_data old_logs])
      expect(entries.map(&:reason)).to eq(%w[Legacy Legacy])
    end

    it "defaults the shared reason to nil when it is omitted" do
      builder.tables(:temp_data, :old_logs)

      expect(builder.build.entries.map(&:reason)).to eq([nil, nil])
    end
  end

  describe "#plugin" do
    subject(:builder) { described_class.new }

    it "records the normalized plugin name with its reason" do
      builder.plugin(:discourse_ai, "Not migrating")

      entries = builder.build.plugin_entries
      expect(entries.size).to eq(1)
      expect(entries.first).to have_attributes(name: "discourse-ai", reason: "Not migrating")
    end

    it "raises a reason error mentioning the plugin when the reason is nil" do
      expect { builder.plugin(:chat, nil) }.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Ignored plugin :chat must have a reason.",
      )
    end

    it "raises when the reason is only whitespace" do
      expect { builder.plugin(:chat, "   ") }.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /must have a reason/,
      )
    end

    it "raises when the same plugin is declared twice" do
      builder.plugin(:discourse_ai, "Not migrating")

      expect { builder.plugin(:"discourse-ai", "again") }.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Ignored plugin :discourse-ai is already declared.",
      )
    end
  end

  describe "#build" do
    subject(:builder) { described_class.new }

    before do
      builder.table(:users, "reason A")
      builder.plugin(:chat, "reason B")
    end

    it "returns the collected table and plugin entries" do
      config = builder.build
      expect(config.entries.map(&:name)).to eq(["users"])
      expect(config.plugin_entries.map(&:name)).to eq(["chat"])
    end

    it "freezes the entry collections" do
      config = builder.build
      expect(config.entries).to be_frozen
      expect(config.plugin_entries).to be_frozen
    end
  end
end
