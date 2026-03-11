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

  def table_config(
    name: "users",
    source_table_name: "users",
    primary_key_columns: ["id"],
    included_column_names: %w[id username],
    column_options: {},
    added_columns: [],
    indexes: [],
    constraints: [],
    ignored_columns_map: {},
    ignore_plugin_columns: false
  )
    Struct
      .new(
        :name,
        :source_table_name,
        :primary_key_columns,
        :included_column_names,
        :column_options,
        :added_columns,
        :indexes,
        :constraints,
        :ignored_columns_map,
        :ignore_plugin_columns,
        keyword_init: true,
      ) do
        def column_options_for(col)
          column_options[col.to_s]
        end

        def ignored_column_names
          ignored_columns_map.keys
        end

        def ignore_reason_for(col)
          ignored_columns_map[col.to_s]
        end

        def ignore_plugin_columns?
          ignore_plugin_columns
        end
      end
      .new(
        name:,
        source_table_name:,
        primary_key_columns:,
        included_column_names:,
        column_options:,
        added_columns:,
        indexes:,
        constraints:,
        ignored_columns_map:,
        ignore_plugin_columns:,
      )
  end

  def diff_result(
    unconfigured_tables: [],
    missing_tables: [],
    stale_ignored_tables: [],
    table_diffs: []
  )
    Struct.new(
      :unconfigured_tables,
      :missing_tables,
      :stale_ignored_tables,
      :table_diffs,
      keyword_init: true,
    ).new(unconfigured_tables:, missing_tables:, stale_ignored_tables:, table_diffs:)
  end

  def table_info(name, plugin: nil)
    Struct.new(:name, :plugin, keyword_init: true).new(name:, plugin:)
  end

  def column_info(name, plugin: nil)
    Struct.new(:name, :plugin, keyword_init: true).new(name:, plugin:)
  end

  def table_diff(
    table_name:,
    unconfigured_columns: [],
    missing_columns: [],
    stale_ignored_columns: [],
    auto_ignored_columns: []
  )
    Struct.new(
      :table_name,
      :unconfigured_columns,
      :missing_columns,
      :stale_ignored_columns,
      :auto_ignored_columns,
      keyword_init: true,
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
    it "prints configured tables, enums, and ignored table count" do
      ignored = double(table_names: Set["z", "a"])

      stub_command
      allow(schema).to receive(:ensure_ready!).with(database: "intermediate_db")
      allow(schema).to receive(:tables).and_return(
        { "users" => table_config, "posts" => table_config(name: "posts") },
      )
      allow(schema).to receive(:enums).and_return({ "visibility" => double, "status" => double })
      allow(schema).to receive(:ignored_tables).and_return(ignored)

      command.list

      expect(command).to have_received(:puts).with("Configured tables (2):")
      expect(command).to have_received(:puts).with("  posts")
      expect(command).to have_received(:puts).with("  users")
      expect(command).to have_received(:puts).with("Enums (2):")
      expect(command).to have_received(:puts).with("  status")
      expect(command).to have_received(:puts).with("  visibility")
      expect(command).to have_received(:puts).with("Ignored tables: 2")
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

  describe "#resolve" do
    it "prints the resolved tables and enums" do
      definition = resolved_schema
      preflight = schema::PreflightResult.new(resolved: definition, errors: [])

      stub_command
      allow(schema).to receive(:preflight).with(database: "intermediate_db").and_return(preflight)

      command.resolve

      expect(command).to have_received(:puts).with("Resolved Schema")
      expect(command).to have_received(:puts).with("Tables (1):")
      expect(command).to have_received(:puts).with("  users (PK: id, 1 columns)")
      expect(command).to have_received(:puts).with("Enums (1):")
      expect(command).to have_received(:puts).with("  visibility: 1 values (integer)")
    end

    it "fails fast when validation errors are present" do
      preflight = schema::PreflightResult.new(resolved: nil, errors: ["bad config"])

      stub_command
      allow(schema).to receive(:preflight).with(database: "intermediate_db").and_return(preflight)
      allow(schema).to receive(:resolve)

      expect { command.resolve }.to raise_error(SystemExit)
      expect(schema).not_to have_received(:resolve)
    end
  end

  describe "#show" do
    it "prints table details for a configured table" do
      table =
        table_config(
          name: "users",
          source_table_name: "legacy_users",
          column_options: {
            "username" =>
              Struct.new(:type, :required, :max_length, :rename_to, keyword_init: true).new(
                type: "text",
                required: true,
                max_length: nil,
                rename_to: nil,
              ),
          },
          added_columns: [
            Struct.new(:name, :type, :required, :enum, keyword_init: true).new(
              name: "status",
              type: "integer",
              required: true,
              enum: "visibility",
            ),
          ],
          indexes: [
            Struct.new(:column_names, :name, :unique, :condition, keyword_init: true).new(
              column_names: ["username"],
              name: "idx_users_username",
              unique: true,
              condition: "username IS NOT NULL",
            ),
          ],
          constraints: [
            Struct.new(:name, :type, :condition, keyword_init: true).new(
              name: "chk_users_username",
              type: :check,
              condition: "username <> ''",
            ),
          ],
          ignored_columns_map: {
            "legacy_id" => "Old source column",
          },
          ignore_plugin_columns: true,
        )

      stub_command
      allow(schema).to receive(:ensure_ready!).with(database: "intermediate_db")
      allow(schema).to receive(:find_table).with("users").and_return(table)

      command.show("users")

      expect(command).to have_received(:puts).with("Table: users")
      expect(command).to have_received(:puts).with("  Source: legacy_users")
      expect(command).to have_received(:puts).with("  Included Columns (2):")
      expect(command).to have_received(:puts).with("    username (type: text, required)")
      expect(command).to have_received(:puts).with("  Added Columns (1):")
      expect(command).to have_received(:puts).with(
        "    status: integer (enum: visibility, required)",
      )
      expect(command).to have_received(:puts).with("  Ignored Columns (1):")
      expect(command).to have_received(:puts).with("    legacy_id: Old source column")
      expect(command).to have_received(:puts).with("  Indexes (1):")
      expect(command).to have_received(:puts).with(
        "    UNIQUE idx_users_username (username) WHERE username IS NOT NULL",
      )
      expect(command).to have_received(:puts).with("  Constraints (1):")
      expect(command).to have_received(:puts).with("    chk_users_username: username <> ''")
      expect(command).to have_received(:puts).with("  Auto-ignore plugin columns: true")
    end

    it "lists available tables and exits when the table is missing" do
      stub_command
      allow(schema).to receive(:ensure_ready!).with(database: "intermediate_db")
      allow(schema).to receive(:find_table).with("unknown").and_return(nil)
      allow(schema).to receive(:tables).and_return(
        { "posts" => table_config(name: "posts"), "users" => table_config },
      )

      expect { command.show("unknown") }.to raise_error(SystemExit)

      expect(command).to have_received(:puts).with(a_string_including("Table 'unknown' not found"))
      expect(command).to have_received(:puts).with("Available tables:")
      expect(command).to have_received(:puts).with("  posts")
      expect(command).to have_received(:puts).with("  users")
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
        "Unconfigured tables (add to tables/ or ignored.rb):",
      )
      expect(command).to have_received(:puts).with("  + chat_channels [chat]")
      expect(command).to have_received(:puts).with(
        "Missing tables (configured but not in database):",
      )
      expect(command).to have_received(:puts).with("  - users")
      expect(command).to have_received(:puts).with("Stale ignored tables (no longer in database):")
      expect(command).to have_received(:puts).with("  ~ legacy_users")
      expect(command).to have_received(:puts).with("Column differences:")
      expect(command).to have_received(:puts).with("  topics:")
      expect(command).to have_received(:puts).with("    + chat_enabled [chat]")
      expect(command).to have_received(:puts).with("    - title")
      expect(command).to have_received(:puts).with("    ~ old_column (ignored but gone)")
      expect(command).to have_received(:puts).with(
        "      poll_enabled [poll] (auto-ignored from plugin)",
      )
      expect(command).to have_received(:puts).with("Suggested actions:")
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
