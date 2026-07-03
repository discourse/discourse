# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::Differ do
  # Specs for the diff result types defined alongside the Differ.

  def table_diff(unconfigured: [], missing: [], stale: [], auto_ignored: [])
    Migrations::Tooling::Schema::DSL::TableDiff.new(
      table_name: "users",
      unconfigured_columns: unconfigured,
      missing_columns: missing,
      stale_ignored_columns: stale,
      auto_ignored_columns: auto_ignored,
    )
  end

  def diff_result(unconfigured_tables: [], missing_tables: [], stale_tables: [], table_diffs: [])
    Migrations::Tooling::Schema::DSL::DiffResult.new(
      unconfigured_tables:,
      missing_tables:,
      stale_ignored_tables: stale_tables,
      table_diffs:,
    )
  end

  def column(name)
    Migrations::Tooling::Schema::DSL::ColumnInfo.new(name:, plugin: nil)
  end

  def table(name)
    Migrations::Tooling::Schema::DSL::TableInfo.new(name:, plugin: nil)
  end

  describe "TableDiff#actionable?" do
    it "is not actionable when empty" do
      expect(table_diff).not_to be_actionable
    end

    it "is actionable for unconfigured, missing or stale ignored columns" do
      expect(table_diff(unconfigured: [column("locale")])).to be_actionable
      expect(table_diff(missing: [column("locale")])).to be_actionable
      expect(table_diff(stale: [column("locale")])).to be_actionable
    end

    it "is not actionable for auto-ignored plugin columns" do
      expect(table_diff(auto_ignored: [column("assignable_level")])).not_to be_actionable
    end
  end

  describe "DiffResult#actionable?" do
    it "is not actionable when empty" do
      expect(diff_result).not_to be_actionable
    end

    it "is actionable for table-level differences" do
      expect(diff_result(unconfigured_tables: [table("users")])).to be_actionable
      expect(diff_result(missing_tables: [table("users")])).to be_actionable
      expect(diff_result(stale_tables: [table("users")])).to be_actionable
    end

    it "is actionable when a table diff is actionable" do
      expect(diff_result(table_diffs: [table_diff(unconfigured: [column("locale")])])).to(
        be_actionable,
      )
    end

    it "is not actionable when table diffs only contain auto-ignored columns" do
      expect(diff_result(table_diffs: [table_diff(auto_ignored: [column("foo")])])).not_to(
        be_actionable,
      )
    end
  end
end
