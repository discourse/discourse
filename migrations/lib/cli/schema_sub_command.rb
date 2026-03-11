# frozen_string_literal: true

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
      print_validation_errors(errors)

      puts "✓ Schema valid".green
    end

    desc "generate", "Generate SQL schema, Ruby models, and enum files"
    def generate
      load_rails!

      database = selected_database
      resolved = Schema.generate(database:)

      puts
      table_count = resolved.tables.size
      enum_count = resolved.enums.size
      tables_str = "#{table_count} #{"table".pluralize(table_count)}"
      enums_str = "#{enum_count} #{"enum".pluralize(enum_count)}"
      puts "✓ Generated #{tables_str}, #{enums_str}".green
    end

    desc "resolve", "Show the resolved schema (for debugging)"
    def resolve
      load_rails!

      database = selected_database
      preflight = Schema.preflight(database:)
      print_validation_errors(preflight.errors)
      resolved = preflight.resolved

      puts "Resolved Schema"
      puts "==============="
      puts
      puts "Tables (#{resolved.tables.size}):"
      resolved.tables.each do |table|
        pk_names = table.primary_key_column_names
        pk = pk_names&.any? ? pk_names.join(", ") : "none"
        puts "  #{table.name} (PK: #{pk}, #{table.columns.size} columns)"
      end
      puts
      puts "Enums (#{resolved.enums.size}):"
      resolved.enums.each do |enum|
        puts "  #{enum.name}: #{enum.values.size} values (#{enum.datatype})"
      end
    end

    desc "list", "List configured tables and enums, plus ignored table count"
    def list
      load_rails!
      database = selected_database
      Schema.ensure_ready!(database:)

      tables = Schema.tables
      ignored = Schema.ignored_tables
      enums = Schema.enums

      puts "Configured tables (#{tables.size}):"
      tables.keys.sort.each { |t| puts "  #{t}" }
      puts

      puts "Enums (#{enums.size}):"
      enums.keys.sort.each { |e| puts "  #{e}" }
      puts

      ignored_count = ignored ? ignored.table_names.size : 0
      puts "Ignored tables: #{ignored_count}"
    end

    desc "show TABLE", "Show configuration details for a table"
    def show(table_name)
      load_rails!
      database = selected_database
      Schema.ensure_ready!(database:)

      table = Schema.find_table(table_name)

      unless table
        puts "Table '#{table_name}' not found in configuration.".red
        puts
        puts "Available tables:"
        Schema.tables.keys.sort.each { |t| puts "  #{t}" }
        exit 1
      end

      display_table(table)
    end

    desc "ignore TABLE", "Add a table to ignored.rb"
    method_option :reason, type: :string, desc: "Optional reason for ignoring the table"
    def ignore(table_name)
      load_rails!

      database = selected_database
      Schema.ignore_table(table_name, reason: options[:reason], database:)
      puts "✓ Added #{table_name} to ignored.rb".green
    end

    desc "diff", "Show differences between configuration and database"
    method_option :verbose, type: :boolean, default: false, desc: "Show auto-ignored plugin columns"
    def diff
      load_rails!

      database = selected_database
      result = Schema.diff(database:)
      display_diff(result, verbose: options[:verbose])
    end

    desc "add TABLE", "Create a config file for a new table"
    def add(table_name)
      load_rails!

      database = selected_database
      path = Schema.add_table(table_name, database:)
      puts "✓ Created #{path}".green
      puts
      puts "Next steps:"
      puts "  1. Edit the file to configure columns"
      puts "  2. Run 'migrations/bin/cli schema validate'"
    end

    desc "refresh-plugins", "Regenerate the plugin manifest"
    method_option :force, type: :boolean, default: false, desc: "Force regeneration"
    def refresh_plugins
      load_rails!

      database = selected_database
      Schema.ensure_ready!(database:, refresh_manifest: false)

      manifest = Schema.plugin_manifest

      if options[:force] || !manifest.fresh? || manifest.incomplete?
        puts "Detecting plugin tables and columns..."
        manifest.regenerate!
        if manifest.incomplete?
          failed_plugins = manifest.failed_plugins.join(", ").presence || "(unknown)"
          puts "Plugin manifest updated with warnings (failed plugins: #{failed_plugins})"
        else
          puts "✓ Plugin manifest updated".green
        end
        puts "  Tables: #{manifest.table_count}"
        puts "  Columns: #{manifest.column_count}"
        puts "  Plugins: #{manifest.all_plugin_names.join(", ")}"
      else
        puts "Plugin manifest is up to date"
        puts "  Use --force to regenerate"
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
          "Schema configuration directory not found: #{Schema.schema_root_path}",
        )
      end

      available = Schema.available_databases
      return if available.include?(database)

      raise(
        Schema::ConfigError,
        "Unknown database '#{database}'. Available: #{available.join(", ")}",
      )
    end

    def selected_database
      database = options[:database].to_s
      validate_database_option!(database)
      database
    end

    def print_validation_errors(errors)
      return if errors.empty?

      errors.each { |e| puts "✗ #{e}".red }
      puts
      error_count = errors.size
      puts "#{error_count} #{"error".pluralize(error_count)}"
      exit 1
    end

    def display_table(table)
      puts "Table: #{table.name}"
      puts "  Source: #{table.source_table_name}" if table.source_table_name != table.name
      puts

      if table.primary_key_columns
        puts "  Primary Key: #{table.primary_key_columns.join(", ")}"
        puts
      end

      if table.included_column_names
        puts "  Included Columns (#{table.included_column_names.size}):"
        table.included_column_names.sort.each do |col|
          opts = table.column_options_for(col)
          extra = []
          extra << "type: #{opts.type}" if opts&.type
          extra << "required" if opts&.required
          extra_str = extra.any? ? " (#{extra.join(", ")})" : ""
          puts "    #{col}#{extra_str}"
        end
      else
        puts "  Columns: all (no explicit include list)"
      end
      puts

      if table.added_columns.any?
        puts "  Added Columns (#{table.added_columns.size}):"
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
        puts "  Ignored Columns (#{table.ignored_column_names.size}):"
        table.ignored_column_names.sort.each do |col|
          reason = table.ignore_reason_for(col)
          puts "    #{col}: #{reason}"
        end
        puts
      end

      if table.indexes.any?
        puts "  Indexes (#{table.indexes.size}):"
        table.indexes.each do |idx|
          unique_str = idx.unique ? "UNIQUE " : ""
          where_str = idx.condition ? " WHERE #{idx.condition}" : ""
          puts "    #{unique_str}#{idx.name} (#{idx.column_names.join(", ")})#{where_str}"
        end
        puts
      end

      if table.constraints.any?
        puts "  Constraints (#{table.constraints.size}):"
        table.constraints.each { |c| puts "    #{c.name}: #{c.condition}" }
        puts
      end

      puts "  Auto-ignore plugin columns: #{table.ignore_plugin_columns?}"
    end

    def display_diff(result, verbose: false)
      has_changes = false

      if result.unconfigured_tables.any?
        has_changes = true
        puts "Unconfigured tables (add to tables/ or ignored.rb):"
        result.unconfigured_tables.each do |t|
          plugin_info = t.plugin ? " [#{t.plugin}]" : ""
          puts "  + #{t.name}#{plugin_info}"
        end
        puts
      end

      if result.missing_tables.any?
        has_changes = true
        puts "Missing tables (configured but not in database):"
        result.missing_tables.each { |t| puts "  - #{t.name}" }
        puts
      end

      if result.stale_ignored_tables.any?
        has_changes = true
        puts "Stale ignored tables (no longer in database):"
        result.stale_ignored_tables.each { |t| puts "  ~ #{t.name}" }
        puts
      end

      table_diffs = filter_table_diffs(result.table_diffs, verbose:)

      if table_diffs.any?
        has_changes = true
        puts "Column differences:"
        table_diffs.each do |table_diff|
          puts "  #{table_diff.table_name}:"

          table_diff.unconfigured_columns.each do |c|
            plugin_info = c.plugin ? " [#{c.plugin}]" : ""
            puts "    + #{c.name}#{plugin_info}"
          end

          table_diff.missing_columns.each { |c| puts "    - #{c.name}" }

          table_diff.stale_ignored_columns.each { |c| puts "    ~ #{c.name} (ignored but gone)" }

          if verbose
            table_diff.auto_ignored_columns.each do |c|
              puts "      #{c.name} [#{c.plugin}] (auto-ignored from plugin)"
            end
          end
        end
        puts
      end

      if has_changes
        puts "Suggested actions:"
        puts "  migrations/bin/cli schema add <table>         Create config for a new table"
        puts "  migrations/bin/cli schema ignore <table> [--reason \"...\"]  Add table to ignored.rb"
      else
        puts "✓ No differences found".green
      end
    end

    def filter_table_diffs(table_diffs, verbose:)
      return table_diffs if verbose

      table_diffs.select do |td|
        td.unconfigured_columns.any? || td.missing_columns.any? || td.stale_ignored_columns.any?
      end
    end
  end
end
