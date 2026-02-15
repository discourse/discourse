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
end
