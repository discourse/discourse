# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::IgnoredBuilder do
  after { Migrations::Database::Schema.reset! }

  describe "Schema.ignored" do
    it "registers ignored tables with reasons" do
      Migrations::Database::Schema.ignored do
        table :schema_migrations, "Rails internal table"
        table :ar_internal_metadata, "Rails internal table"
      end

      ignored = Migrations::Database::Schema.ignored_tables
      expect(ignored.ignored?(:schema_migrations)).to be true
      expect(ignored.ignored?(:ar_internal_metadata)).to be true
      expect(ignored.ignored?(:users)).to be false
    end

    it "supports batch ignore with shared reason" do
      Migrations::Database::Schema.ignored { tables :temp_data, :old_logs, reason: "Legacy tables" }

      ignored = Migrations::Database::Schema.ignored_tables
      expect(ignored.table_names).to eq(Set[:temp_data, :old_logs])
      expect(ignored.reason_for(:temp_data)).to eq("Legacy tables")
      expect(ignored.reason_for(:old_logs)).to eq("Legacy tables")
    end

    it "raises when reason is missing" do
      expect do Migrations::Database::Schema.ignored { table :bad_table, "" } end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /reason/,
      )
    end

    it "raises when batch reason is missing" do
      expect do
        Migrations::Database::Schema.ignored { tables :a, :b, reason: "" }
      end.to raise_error(Migrations::Database::Schema::ConfigError, /reason/)
    end
  end

  describe "plugin DSL" do
    it "registers ignored plugins with reasons" do
      Migrations::Database::Schema.ignored do
        plugin :chat, "Not needed for migration"
        plugin :polls, "Legacy plugin"
      end

      ignored = Migrations::Database::Schema.ignored_tables
      expect(ignored.ignored_plugin_names).to eq(%i[chat polls])
      expect(ignored.plugin_ignored?(:chat)).to be true
      expect(ignored.plugin_ignored?(:polls)).to be true
      expect(ignored.plugin_ignored?(:discourse_ai)).to be false
    end

    it "raises when plugin reason is missing" do
      expect do Migrations::Database::Schema.ignored { plugin :chat, "" } end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /reason/,
      )
    end

    it "raises when plugin reason is nil" do
      expect do Migrations::Database::Schema.ignored { plugin :chat, nil } end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /reason/,
      )
    end

    it "coexists with table ignores" do
      Migrations::Database::Schema.ignored do
        table :schema_migrations, "Rails internal"
        plugin :chat, "Not migrating"
      end

      ignored = Migrations::Database::Schema.ignored_tables
      expect(ignored.ignored?(:schema_migrations)).to be true
      expect(ignored.plugin_ignored?(:chat)).to be true
      expect(ignored.table_names).to eq(Set[:schema_migrations])
      expect(ignored.ignored_plugin_names).to eq(%i[chat])
    end
  end
end
