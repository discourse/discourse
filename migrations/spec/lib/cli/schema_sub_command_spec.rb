# frozen_string_literal: true

require "thor"

RSpec.describe Migrations::CLI::SchemaSubCommand do
  let(:command) { described_class.new }
  let(:schema) { Migrations::Database::Schema }

  def stub_command(options = {})
    allow(command).to receive(:load_rails!)
    allow(command).to receive(:puts)
    allow(command).to receive(:options).and_return(
      { database: "intermediate_db", verbose: false, force: false }.merge(options),
    )
    allow(schema).to receive(:available_databases).and_return(%w[intermediate_db])
  end

  def resolved_schema(table_name: "users", enum_name: "visibility")
    table =
      schema::TableDefinition.new(
        name: table_name,
        columns: [
          schema::ColumnDefinition.new(
            name: "id",
            datatype: :integer,
            nullable: false,
            max_length: nil,
            is_primary_key: true,
            enum: nil,
          ),
        ],
        indexes: [],
        primary_key_column_names: ["id"],
        constraints: [],
        model_mode: nil,
      )

    enum =
      schema::EnumDefinition.new(name: enum_name, values: { "public" => 0 }, datatype: :integer)

    schema::Definition.new(tables: [table], enums: [enum])
  end

  def diff_result(
    unconfigured_tables: [],
    missing_tables: [],
    stale_ignored_tables: [],
    table_diffs: []
  )
    Data.define(:unconfigured_tables, :missing_tables, :stale_ignored_tables, :table_diffs).new(
      unconfigured_tables:,
      missing_tables:,
      stale_ignored_tables:,
      table_diffs:,
    )
  end

  def table_info(name, plugin: nil)
    Data.define(:name, :plugin).new(name:, plugin:)
  end

  def column_info(name, plugin: nil)
    Data.define(:name, :plugin).new(name:, plugin:)
  end

  def table_diff(
    table_name:,
    unconfigured_columns: [],
    missing_columns: [],
    stale_ignored_columns: [],
    auto_ignored_columns: []
  )
    Data.define(
      :table_name,
      :unconfigured_columns,
      :missing_columns,
      :stale_ignored_columns,
      :auto_ignored_columns,
    ).new(
      table_name:,
      unconfigured_columns:,
      missing_columns:,
      stale_ignored_columns:,
      auto_ignored_columns:,
    )
  end

  describe "#generate" do
    it "prints a summary for the generated schema" do
      definition = resolved_schema

      stub_command
      allow(schema).to receive(:generate).with(database: "intermediate_db").and_return(definition)

      command.generate

      expect(command).to have_received(:puts).with(a_string_including("Generated 1 table, 1 enum"))
    end

    it "raises when the selected database is unknown" do
      stub_command(database: "archive_db")
      allow(schema).to receive(:available_databases).and_return(%w[intermediate_db])
      allow(schema).to receive(:generate)

      expect { command.generate }.to raise_error(
        schema::ConfigError,
        /Unknown database 'archive_db'/,
      )
      expect(schema).not_to have_received(:generate)
    end
  end

  describe "#ignore" do
    it "allows adding ignored tables without a reason" do
      stub_command
      allow(schema).to receive(:ignore_table).with(
        "users",
        reason: nil,
        database: "intermediate_db",
      )

      command.ignore("users")

      expect(schema).to have_received(:ignore_table).with(
        "users",
        reason: nil,
        database: "intermediate_db",
      )
    end
  end

  describe "#list" do
    it "prints configured tables, enums, and ignored table counts" do
      ignored = double(table_names: Set["z", "a"], ignored_plugin_names: %w[chat])

      stub_command
      allow(schema).to receive(:ensure_ready!).with(database: "intermediate_db")
      allow(schema).to receive(:tables).and_return({ "users" => double, "posts" => double })
      allow(schema).to receive(:enums).and_return({ "visibility" => double, "status" => double })
      allow(schema).to receive(:ignored_tables).and_return(ignored)
      allow(schema).to receive(:effective_ignored_table_names).with(
        database: "intermediate_db",
      ).and_return(Set["z", "a", "chat_messages"])

      command.list

      expect(command).to have_received(:puts).with("Configured tables (2):")
      expect(command).to have_received(:puts).with("  posts")
      expect(command).to have_received(:puts).with("  users")
      expect(command).to have_received(:puts).with("Enums (2):")
      expect(command).to have_received(:puts).with("  status")
      expect(command).to have_received(:puts).with("  visibility")
      expect(command).to have_received(:puts).with("Ignored tables: 2 explicit, 3 effective")
      expect(command).to have_received(:puts).with("Ignored plugins: 1")
    end
  end

  describe "#refresh_plugins" do
    it "reports incomplete manifest regeneration" do
      manifest = instance_double(Migrations::Database::Schema::DSL::PluginManifest)
      allow(manifest).to receive(:fresh?).and_return(false)
      allow(manifest).to receive(:regenerate!)
      allow(manifest).to receive(:incomplete?).and_return(true)
      allow(manifest).to receive(:failed_plugins).and_return(%w[chat])
      allow(manifest).to receive(:table_count).and_return(1)
      allow(manifest).to receive(:column_count).and_return(2)
      allow(manifest).to receive(:all_plugin_names).and_return(%w[chat])

      stub_command
      allow(command).to receive(:options).and_return(
        { database: "intermediate_db", force: false, verbose: false },
      )

      allow(schema).to receive(:ensure_ready!).with(
        database: "intermediate_db",
        refresh_manifest: false,
      )
      allow(schema).to receive(:plugin_manifest).and_return(manifest)

      command.refresh_plugins

      expect(command).to have_received(:puts).with(
        "Plugin manifest updated with warnings (failed plugins: chat)",
      )
    end
  end

  describe "#diff" do
    it "prints the detailed diff and suggestions" do
      result =
        diff_result(
          unconfigured_tables: [table_info("chat_channels", plugin: "chat")],
          missing_tables: [table_info("users")],
          stale_ignored_tables: [table_info("legacy_users")],
          table_diffs: [
            table_diff(
              table_name: "topics",
              unconfigured_columns: [column_info("chat_enabled", plugin: "chat")],
              missing_columns: [column_info("title")],
              stale_ignored_columns: [column_info("old_column")],
              auto_ignored_columns: [column_info("poll_enabled", plugin: "poll")],
            ),
          ],
        )

      stub_command(verbose: true)
      allow(schema).to receive(:diff).with(database: "intermediate_db").and_return(result)

      command.diff

      expect(command).to have_received(:puts).with(
        a_string_including(
          "Unconfigured tables",
          "+ chat_channels [chat]",
          "Missing tables",
          "- users",
          "Stale ignored tables",
          "~ legacy_users",
          "Column differences",
          "topics:",
          "+ chat_enabled [chat]",
          "- title",
          "~ old_column (ignored but gone)",
          "poll_enabled [poll] (auto-ignored from plugin)",
        ),
      )
      expect(command).to have_received(:puts).with(a_string_including("Suggested actions:"))
    end

    it "prints a no-differences message when the schema matches the database" do
      stub_command
      allow(schema).to receive(:diff).with(database: "intermediate_db").and_return(diff_result)

      command.diff

      expect(command).to have_received(:puts).with(a_string_including("No differences found"))
    end
  end

  describe "#add" do
    it "prints the created file path and next steps" do
      stub_command
      allow(schema).to receive(:add_table).with("users", database: "intermediate_db").and_return(
        "/tmp/users.rb",
      )

      command.add("users")

      expect(command).to have_received(:puts).with(a_string_including("Created /tmp/users.rb"))
      expect(command).to have_received(:puts).with("Next steps:")
      expect(command).to have_received(:puts).with("  1. Edit the file to configure columns")
      expect(command).to have_received(:puts).with("  2. Run 'migrations/bin/cli schema validate'")
    end
  end

  describe "#validate" do
    it "treats resolved schema errors as validation failures" do
      stub_command
      allow(schema).to receive(:validate).with(database: "intermediate_db").and_return(
        ["resolved schema problem"],
      )

      expect { command.validate }.to raise_error(SystemExit)
    end
  end
end
