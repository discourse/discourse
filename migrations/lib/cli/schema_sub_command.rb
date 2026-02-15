# frozen_string_literal: true

module Migrations::CLI
  class SchemaSubCommand < Thor
    Schema = ::Migrations::Database::Schema

    desc "validate", "Validate schema configuration against the database"
    method_option :strict, type: :boolean, default: false, desc: "Treat warnings as errors (for CI)"
    def validate
      load_rails!
      Schema.ensure_ready!

      result = Schema.validate

      result.warnings.each { |w| puts "⚠ #{w}".yellow }
      result.errors.each { |e| puts "✗ #{e}".red }

      has_issues = result.errors.any? || (options[:strict] && result.warnings.any?)

      if has_issues
        puts
        puts "#{result.errors.size} error(s), #{result.warnings.size} warning(s)"
        exit 1
      else
        puts "✓ Schema valid".green
      end
    end

    desc "generate", "Generate SQL schema, Ruby models, and enum files"
    def generate
      load_rails!

      resolved = Schema.generate

      puts
      puts "✓ Generated #{resolved.tables.size} table(s), #{resolved.enums.size} enum(s)".green
    end

    desc "resolve", "Show the resolved schema (for debugging)"
    def resolve
      load_rails!

      resolved = Schema.resolve

      puts "Resolved Schema"
      puts "==============="
      puts
      puts "Tables (#{resolved.tables.size}):"
      resolved.tables.each do |table|
        pk = table.primary_key_column_names&.join(", ") || "id"
        puts "  #{table.name} (PK: #{pk}, #{table.columns.size} columns)"
      end
      puts
      puts "Enums (#{resolved.enums.size}):"
      resolved.enums.each do |enum|
        puts "  #{enum.name}: #{enum.values.size} values (#{enum.datatype})"
      end
    end

    desc "list", "List all configured, ignored tables and enums"
    def list
      load_rails!
      Schema.ensure_ready!

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
      Schema.ensure_ready!

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
    method_option :reason, type: :string, required: true, desc: "Reason for ignoring the table"
    def ignore(table_name)
      reason = options[:reason]

      ignored_path = File.join(Schema.config_path, "ignored.rb")

      unless File.exist?(ignored_path)
        raise Schema::ConfigError, "ignored.rb not found at #{ignored_path}"
      end

      content = File.read(ignored_path)

      new_entry = "  table :#{table_name}, \"#{reason}\"\n"
      content.sub!(/(\nend\s*)\z/, "\n#{new_entry}\\1")

      File.write(ignored_path, content)
      puts "✓ Added #{table_name} to ignored.rb".green
    end

    desc "diff", "Show differences between configuration and database"
    def diff
      load_rails!
      Schema.ensure_ready!

      result = Schema.diff
      display_diff(result)
    end

    desc "scaffold TABLE", "Create a config file for a new table"
    def scaffold(table_name)
      load_rails!
      Schema.ensure_ready!

      path = Schema.scaffold(table_name)
      puts "✓ Created #{path}".green
      puts
      puts "Next steps:"
      puts "  1. Edit the file to configure columns"
      puts "  2. Run 'bin/cli schema validate'"
    end

    desc "detect-plugins", "Regenerate the plugin manifest"
    method_option :force, type: :boolean, default: false, desc: "Force regeneration"
    def detect_plugins
      load_rails!

      manifest = Schema.plugin_manifest

      if options[:force] || !manifest.fresh?
        puts "Detecting plugin tables and columns..."
        manifest.regenerate!
        puts "✓ Plugin manifest updated".green
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

    def display_table(table)
      puts "Table: #{table.name}"
      puts "  Source: #{table.source_table_name}" if table.source_table_name != table.name
      puts "  Plugin: #{table.plugin_name}" if table.plugin_name
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

    def display_diff(result)
      has_changes = false

      if result.unknown_tables.any?
        has_changes = true
        puts "Unknown tables (add to tables/ or ignored.rb):"
        result.unknown_tables.each do |t|
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

      if result.table_diffs.any?
        has_changes = true
        puts "Column differences:"
        result.table_diffs.each do |table_diff|
          puts "  #{table_diff.table_name}:"

          table_diff.unknown_columns.each do |c|
            plugin_info = c.plugin ? " [#{c.plugin}]" : ""
            puts "    + #{c.name}#{plugin_info}"
          end

          table_diff.missing_columns.each { |c| puts "    - #{c.name}" }

          table_diff.stale_ignored_columns.each { |c| puts "    ~ #{c.name} (ignored but gone)" }
        end
        puts
      end

      if has_changes
        puts "Suggested actions:"
        puts "  bin/cli schema scaffold <table>    Create config for a new table"
        puts "  bin/cli schema ignore <table>      Add table to ignored.rb"
      else
        puts "✓ No differences found".green
      end
    end
  end
end
