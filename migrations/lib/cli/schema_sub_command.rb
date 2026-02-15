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

    desc "migrate_config", "Convert YAML config to DSL format"
    method_option :yaml_path,
                  type: :string,
                  desc: "Path to YAML config file",
                  default: nil,
                  banner: "path"
    method_option :output_path,
                  type: :string,
                  desc: "Output directory for DSL files",
                  default: nil,
                  banner: "path"
    def migrate_config
      yaml_path =
        options[:yaml_path] || File.join(::Migrations.root_path, "config", "intermediate_db.yml")
      output_path = options[:output_path] || Schema.config_path

      unless File.exist?(yaml_path)
        puts "Error: YAML config not found at #{yaml_path}".red
        exit 1
      end

      if Dir.exist?(output_path) && Dir.glob(File.join(output_path, "**/*.rb")).any?
        puts "Error: Output directory already has config files: #{output_path}".red
        puts "       Remove them first or specify a different --output-path"
        exit 1
      end

      puts "Migrating YAML config to DSL format..."
      puts "  From: #{yaml_path}"
      puts "  To:   #{output_path}"
      puts

      Schema::DSL::ConfigMigrator.new(yaml_path, output_path).migrate!

      puts
      puts "Migration complete!".green
      puts
      puts "Next steps:"
      puts "  1. Review the generated files"
      puts "  2. Run 'bin/cli schema validate' to check for issues"
      puts "  3. Run 'bin/cli schema generate' to test generation"
      puts "  4. Delete the old YAML config"
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
  end
end
