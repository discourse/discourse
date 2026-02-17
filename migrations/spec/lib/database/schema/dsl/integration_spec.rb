# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL do
  after { Migrations::Database::Schema.reset! }

  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  def mock_db_columns(columns_hash)
    columns_hash.map do |name, attrs|
      col = instance_double(ActiveRecord::ConnectionAdapters::Column)
      allow(col).to receive_messages(
        name: name.to_s,
        type: attrs[:type] || :text,
        null: attrs.fetch(:null, true),
        default: attrs[:default],
        limit: attrs[:limit],
      )
      col
    end
  end

  def stub_database(connection, db_tables: [], table_columns: {}, primary_keys: {})
    allow(ActiveRecord::Base).to receive(:with_connection).and_yield(connection)
    allow(connection).to receive(:tables).and_return(db_tables.map(&:to_s))

    allow(connection).to receive(:primary_keys) do |table_name|
      primary_keys.fetch(table_name.to_sym) { primary_keys.fetch(table_name.to_s, []) }
    end

    table_columns.each do |table_name, columns|
      allow(connection).to receive(:columns).with(table_name.to_s).and_return(
        mock_db_columns(columns),
      )
    end
  end

  describe "plugin-name normalization end-to-end" do
    it "normalizes underscored ignored plugin names through validator and differ" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:available?).and_return(true)
      allow(manifest).to receive(:tables_for_plugin).with("discourse-ai").and_return(%w[ai_tools])
      allow(manifest).to receive(:plugin_for_table).and_return(nil)
      allow(manifest).to receive(:plugin_for_table).with("ai_tools").and_return("discourse-ai")
      allow(manifest).to receive(:columns_for_plugin).with(
        "discourse-ai",
        table: "users",
      ).and_return(%w[ai_summary])
      allow(manifest).to receive(:columns_for_plugin).with(
        "discourse-ai",
        table: "ai_tools",
      ).and_return([])
      allow(manifest).to receive(:all_plugin_names).and_return(%w[discourse-ai])
      allow(manifest).to receive(:plugin_for_column).and_return(nil)
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      schema = Migrations::Database::Schema
      schema.table(:users) { include :id, :username }
      schema.table(:ai_tools) { include_all }
      schema.ignored { plugin :discourse_ai, "Not migrating" }

      stub_database(
        connection,
        db_tables: %i[users ai_tools],
        table_columns: {
          users: {
            id: {
              type: :integer,
              null: false,
            },
            username: {
              type: :text,
              null: false,
            },
            ai_summary: {
              type: :text,
              null: true,
            },
          },
          ai_tools: {
            id: {
              type: :integer,
              null: false,
            },
          },
        },
      )

      validator_errors =
        Migrations::Database::Schema::DSL::Validator.new(Migrations::Database::Schema).validate
      expect(validator_errors).to include(match(/belongs to ignored plugin 'discourse-ai'/))

      differ_result =
        Migrations::Database::Schema::DSL::Differ.new(Migrations::Database::Schema).diff
      expect(differ_result.unknown_tables.map(&:name)).not_to include("ai_tools")

      user_diff = differ_result.table_diffs.find { |d| d.table_name == "users" }
      expect(user_diff).not_to be_nil
      expect(user_diff.auto_ignored_columns.map(&:name)).to include("ai_summary")
      expect(user_diff.unknown_columns.map(&:name)).not_to include("ai_summary")
    end
  end

  describe "stale manifest regeneration failure" do
    it "propagates regeneration errors from ensure_ready!" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:checksums_fresh?).and_return(false)
      allow(manifest).to receive(:regenerate!).and_raise(
        StandardError,
        "introspection failed: cannot connect",
      )
      allow(Migrations::Database::Schema).to receive(:plugin_manifest).and_return(manifest)

      expect { Migrations::Database::Schema.ensure_ready! }.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /introspection failed/,
      )
    end
  end
end
