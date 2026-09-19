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
end
