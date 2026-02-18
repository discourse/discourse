# frozen_string_literal: true

require "prism"

module Migrations::CLI
  class SchemaSubCommand < Thor
    Schema = ::Migrations::Database::Schema

    class_option :database,
                 aliases: %w[--db],
                 type: :string,
                 default: "intermediate_db",
                 desc: "Database configuration to use"

    desc "validate", "Validate schema configuration against the database"
    def validate
      load_rails!

      database = selected_database

      errors = Schema.validate(database:)

      errors.each { |e| puts I18n.t("schema.validate.error", message: e).red }

      if errors.any?
        puts
        puts I18n.t("schema.validate.summary", count: errors.size)
        exit 1
      else
        puts I18n.t("schema.validate.valid").green
      end
    end

    desc "generate", "Generate SQL schema, Ruby models, and enum files"
    def generate
      load_rails!

      database = selected_database
      resolved = Schema.generate(database:)

      puts
      tables_str = I18n.t("schema.generate.tables", count: resolved.tables.size)
      enums_str = I18n.t("schema.generate.enums", count: resolved.enums.size)
      puts I18n.t("schema.generate.success", tables: tables_str, enums: enums_str).green
    end

    desc "resolve", "Show the resolved schema (for debugging)"
    def resolve
      load_rails!

      database = selected_database

      errors = Schema.validate(database:)
      if errors.any?
        errors.each { |e| puts I18n.t("schema.validate.error", message: e).red }
        puts
        puts I18n.t("schema.validate.summary", count: errors.size)
        exit 1
      end

      resolved = Schema.resolve(database:)

      puts I18n.t("schema.resolve.title")
      puts I18n.t("schema.resolve.separator")
      puts
      puts I18n.t("schema.resolve.tables_header", count: resolved.tables.size)
      resolved.tables.each do |table|
        pk_names = table.primary_key_column_names
        pk = pk_names&.any? ? pk_names.join(", ") : "none"
        puts "  #{table.name} (PK: #{pk}, #{table.columns.size} columns)"
      end
      puts
      puts I18n.t("schema.resolve.enums_header", count: resolved.enums.size)
      resolved.enums.each do |enum|
        puts "  #{enum.name}: #{enum.values.size} values (#{enum.datatype})"
      end
    end

    desc "list", "List all configured, ignored tables and enums"
    def list
      load_rails!
      database = selected_database
      Schema.ensure_ready!(database:)

      tables = Schema.tables
      ignored = Schema.ignored_tables
      enums = Schema.enums

      puts I18n.t("schema.list.configured_tables", count: tables.size)
      tables.keys.sort.each { |t| puts "  #{t}" }
      puts

      puts I18n.t("schema.list.enums", count: enums.size)
      enums.keys.sort.each { |e| puts "  #{e}" }
      puts

      ignored_count = ignored ? ignored.table_names.size : 0
      puts I18n.t("schema.list.ignored_tables", count: ignored_count)
    end

    desc "show TABLE", "Show configuration details for a table"
    def show(table_name)
      load_rails!
      database = selected_database
      Schema.ensure_ready!(database:)

      table = Schema.find_table(table_name)

      unless table
        puts I18n.t("schema.show.table_not_found", name: table_name).red
        puts
        puts I18n.t("schema.show.available_tables")
        Schema.tables.keys.sort.each { |t| puts "  #{t}" }
        exit 1
      end

      display_table(table)
    end

    desc "ignore TABLE", "Add a table to ignored.rb"
    method_option :reason, type: :string, desc: "Optional reason for ignoring the table"
    def ignore(table_name)
      table_name = table_name.to_s
      database = selected_database
      reason = options[:reason]

      unless /\A[a-z0-9_]+\z/.match?(table_name)
        raise(
          Schema::ConfigError,
          "Invalid table name '#{table_name}'. Use lowercase letters, numbers, and underscores.",
        )
      end

      ignored_path = File.join(Schema.config_path(database), "ignored.rb")

      unless File.exist?(ignored_path)
        raise Schema::ConfigError, "ignored.rb not found at #{ignored_path}"
      end

      content = File.read(ignored_path)
      ignored_data = ignored_block_data(content, path: ignored_path)
      if ignored_data[:ignored_table_names].include?(table_name)
        raise Schema::ConfigError, I18n.t("schema.ignore.already_ignored", table: table_name)
      end

      new_entry = build_ignored_table_entry(table_name, reason)
      insert_at = ignored_data[:end_offset]
      content.insert(insert_at, new_entry)

      File.write(ignored_path, content)
      puts I18n.t("schema.ignore.success", table: table_name).green
    end

    desc "diff", "Show differences between configuration and database"
    method_option :verbose, type: :boolean, default: false, desc: "Show auto-ignored plugin columns"
    def diff
      load_rails!

      database = selected_database
      Schema.ensure_ready!(database:)

      result = Schema.diff(database:)
      display_diff(result, verbose: options[:verbose])
    end

    desc "add TABLE", "Create a config file for a new table"
    def add(table_name)
      load_rails!

      database = selected_database
      Schema.ensure_ready!(database:)

      path = Schema.add_table(table_name, database:)
      puts I18n.t("schema.add_table.success", path:).green
      puts
      puts I18n.t("schema.add_table.next_steps")
      puts "  #{I18n.t("schema.add_table.step_edit")}"
      puts "  #{I18n.t("schema.add_table.step_validate")}"
    end

    desc "detect-plugins", "Regenerate the plugin manifest"
    method_option :force, type: :boolean, default: false, desc: "Force regeneration"
    def detect_plugins
      load_rails!

      database = selected_database
      Schema.ensure_ready!(database:, refresh_manifest: false)

      manifest = Schema.plugin_manifest(database:)

      if options[:force] || !manifest.fresh?
        puts I18n.t("schema.detect_plugins.detecting")
        manifest.regenerate!
        if manifest.incomplete?
          failed_plugins = manifest.failed_plugins.join(", ").presence || "(unknown)"
          puts I18n.t("schema.detect_plugins.updated_incomplete", failed_plugins:)
        else
          puts I18n.t("schema.detect_plugins.updated").green
        end
        puts "  #{I18n.t("schema.detect_plugins.tables", count: manifest.table_count)}"
        puts "  #{I18n.t("schema.detect_plugins.columns", count: manifest.column_count)}"
        puts "  #{I18n.t("schema.detect_plugins.plugins", names: manifest.all_plugin_names.join(", "))}"
      else
        puts I18n.t("schema.detect_plugins.up_to_date")
        puts "  #{I18n.t("schema.detect_plugins.use_force")}"
      end
    end

    private

    def load_rails!
      ::Migrations.load_rails_environment(quiet: true)
    end

    def validate_database_option!(database)
      unless File.directory?(Schema.schema_root_path)
        raise(
          Schema::ConfigError,
          I18n.t("schema.config_root_not_found", path: Schema.schema_root_path),
        )
      end

      available = Schema.available_databases
      return if available.include?(database)

      raise(
        Schema::ConfigError,
        I18n.t("schema.unknown_database", name: database, available: available.join(", ")),
      )
    end

    def selected_database
      database = options[:database].to_s
      validate_database_option!(database)
      database
    end

    def build_ignored_table_entry(table_name, reason)
      return "  table :#{table_name}, #{reason.inspect}\n" if reason.present?

      "  table :#{table_name}\n"
    end

    def ignored_block_data(content, path:)
      result = Prism.parse(content)
      unless result.success?
        details = result.errors.map(&:message).join(", ")
        raise Schema::ConfigError, "Could not parse #{path}: #{details}"
      end

      ignored_call = find_ignored_call(result.value)
      if ignored_call.nil?
        raise Schema::ConfigError,
              "Could not find `Migrations::Database::Schema.ignored do ... end` in #{path}"
      end

      {
        end_offset: ignored_call.block.closing_loc.start_offset,
        ignored_table_names: extract_ignored_table_names(ignored_call.block),
      }
    end

    def find_ignored_call(node)
      return node if node.is_a?(Prism::CallNode) && ignored_call_with_block?(node)

      node.compact_child_nodes.each do |child|
        ignored_call = find_ignored_call(child)
        return ignored_call unless ignored_call.nil?
      end

      nil
    end

    def ignored_call_with_block?(node)
      return false unless node.message.to_s == "ignored"
      return false unless node.block

      receiver = node.receiver
      return false unless receiver.is_a?(Prism::ConstantPathNode)

      receiver.full_name.to_s.sub(/\A::/, "") == "Migrations::Database::Schema"
    end

    def extract_ignored_table_names(block_node)
      names = Set.new
      body = block_node&.body
      return names unless body.is_a?(Prism::StatementsNode)

      body.body.each do |statement|
        next unless statement.is_a?(Prism::CallNode)

        message = statement.message.to_s
        next unless message == "table" || message == "tables"

        args = statement.arguments&.arguments || []
        args.each { |arg| names << arg.unescaped if arg.is_a?(Prism::SymbolNode) }
      end

      names
    end

    def display_table(table)
      puts I18n.t("schema.show.table_name", name: table.name)
      if table.source_table_name != table.name
        puts "  #{I18n.t("schema.show.source", name: table.source_table_name)}"
      end
      puts "  #{I18n.t("schema.show.plugin", name: table.plugin_name)}" if table.plugin_name
      puts

      if table.primary_key_columns
        puts "  #{I18n.t("schema.show.primary_key", columns: table.primary_key_columns.join(", "))}"
        puts
      end

      if table.included_column_names
        puts "  #{I18n.t("schema.show.included_columns", count: table.included_column_names.size)}"
        table.included_column_names.sort.each do |col|
          opts = table.column_options_for(col)
          extra = []
          extra << "type: #{opts.type}" if opts&.type
          extra << "required" if opts&.required
          extra_str = extra.any? ? " (#{extra.join(", ")})" : ""
          puts "    #{col}#{extra_str}"
        end
      else
        puts "  #{I18n.t("schema.show.all_columns")}"
      end
      puts

      if table.added_columns.any?
        puts "  #{I18n.t("schema.show.added_columns", count: table.added_columns.size)}"
        table.added_columns.each do |col|
          extra = []
          extra << "enum: #{col.enum}" if col.enum
          extra << "required" if col.required
          extra_str = extra.any? ? " (#{extra.join(", ")})" : ""
          puts "    #{col.name}: #{col.type}#{extra_str}"
        end
        puts
      end

      if table.ignored_column_names.any?
        puts "  #{I18n.t("schema.show.ignored_columns", count: table.ignored_column_names.size)}"
        table.ignored_column_names.sort.each do |col|
          reason = table.ignore_reason_for(col)
          puts "    #{col}: #{reason}"
        end
        puts
      end

      if table.indexes.any?
        puts "  #{I18n.t("schema.show.indexes", count: table.indexes.size)}"
        table.indexes.each do |idx|
          unique_str = idx.unique ? "UNIQUE " : ""
          where_str = idx.condition ? " WHERE #{idx.condition}" : ""
          puts "    #{unique_str}#{idx.name} (#{idx.column_names.join(", ")})#{where_str}"
        end
        puts
      end

      if table.constraints.any?
        puts "  #{I18n.t("schema.show.constraints", count: table.constraints.size)}"
        table.constraints.each { |c| puts "    #{c.name}: #{c.condition}" }
        puts
      end

      puts "  #{I18n.t("schema.show.auto_ignore_plugins", value: table.ignore_plugin_columns?)}"
    end

    def display_diff(result, verbose: false)
      has_changes = false

      if result.unknown_tables.any?
        has_changes = true
        puts I18n.t("schema.diff.unknown_tables")
        result.unknown_tables.each do |t|
          plugin_info = t.plugin ? " [#{t.plugin}]" : ""
          puts "  + #{t.name}#{plugin_info}"
        end
        puts
      end

      if result.missing_tables.any?
        has_changes = true
        puts I18n.t("schema.diff.missing_tables")
        result.missing_tables.each { |t| puts "  - #{t.name}" }
        puts
      end

      if result.stale_ignored_tables.any?
        has_changes = true
        puts I18n.t("schema.diff.stale_ignored")
        result.stale_ignored_tables.each { |t| puts "  ~ #{t.name}" }
        puts
      end

      table_diffs = filter_table_diffs(result.table_diffs, verbose:)

      if table_diffs.any?
        has_changes = true
        puts I18n.t("schema.diff.column_diffs")
        table_diffs.each do |table_diff|
          puts "  #{table_diff.table_name}:"

          table_diff.unknown_columns.each do |c|
            plugin_info = c.plugin ? " [#{c.plugin}]" : ""
            puts "    + #{c.name}#{plugin_info}"
          end

          table_diff.missing_columns.each { |c| puts "    - #{c.name}" }

          table_diff.stale_ignored_columns.each do |c|
            puts "    ~ #{I18n.t("schema.diff.stale_ignored_column", name: c.name)}"
          end

          if verbose
            table_diff.auto_ignored_columns.each do |c|
              puts "    #{I18n.t("schema.diff.auto_ignored_column", name: c.name, plugin: c.plugin)}"
            end
          end
        end
        puts
      end

      if has_changes
        puts I18n.t("schema.diff.suggested_actions")
        puts "  #{I18n.t("schema.diff.action_add")}"
        puts "  #{I18n.t("schema.diff.action_ignore")}"
      else
        puts I18n.t("schema.diff.no_differences").green
      end
    end

    def filter_table_diffs(table_diffs, verbose:)
      return table_diffs if verbose

      table_diffs.select do |td|
        td.unknown_columns.any? || td.missing_columns.any? || td.stale_ignored_columns.any?
      end
    end
  end
end
