# frozen_string_literal: true

module Migrations
  module CLI
    class SchemaSubCommand < Thor
      remove_command :tree

      Schema = Database::Schema

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

      desc "list", "List configured tables and enums, plus ignored table counts"
      def list
        load_rails!
        database = selected_database
        Schema.ensure_ready!(database:)

        tables = Schema.tables
        ignored = Schema.ignored_tables
        effective_ignored = Schema.effective_ignored_table_names(database:)
        enums = Schema.enums

        puts "Configured tables (#{tables.size}):"
        tables.keys.sort.each { |t| puts "  #{t}" }
        puts

        puts "Enums (#{enums.size}):"
        enums.keys.sort.each { |e| puts "  #{e}" }
        puts

        explicit_ignored_count = ignored ? ignored.table_names.size : 0
        effective_ignored_count = effective_ignored.size
        ignored_plugin_count = ignored ? ignored.ignored_plugin_names.size : 0

        puts "Ignored tables: #{explicit_ignored_count} explicit, #{effective_ignored_count} effective"
        puts "Ignored plugins: #{ignored_plugin_count}"
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
      method_option :verbose,
                    type: :boolean,
                    default: false,
                    desc: "Show auto-ignored plugin columns"
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
        Migrations.load_rails_environment(quiet: true)
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

      def display_diff(result, verbose: false)
        sections = []

        if result.unconfigured_tables.any?
          lines = ["Unconfigured tables (add to tables/ or ignored.rb):".bold]
          result.unconfigured_tables.each do |t|
            plugin_info = t.plugin ? " [#{t.plugin}]" : ""
            lines << "  + #{t.name}#{plugin_info}".green
          end
          sections << lines.join("\n")
        end

        if result.missing_tables.any?
          lines = ["Missing tables (configured but not in database):".bold]
          result.missing_tables.each { |t| lines << "  - #{t.name}".red }
          sections << lines.join("\n")
        end

        if result.stale_ignored_tables.any?
          lines = ["Stale ignored tables (no longer in database):".bold]
          result.stale_ignored_tables.each { |t| lines << "  ~ #{t.name}".yellow }
          sections << lines.join("\n")
        end

        table_diffs = filter_table_diffs(result.table_diffs, verbose:)

        if table_diffs.any?
          lines = ["Column differences:".bold]
          table_diffs.each do |table_diff|
            lines << "  #{table_diff.table_name}:".bold

            table_diff.unconfigured_columns.each do |c|
              plugin_info = c.plugin ? " [#{c.plugin}]" : ""
              lines << "    + #{c.name}#{plugin_info}".green
            end

            table_diff.missing_columns.each { |c| lines << "    - #{c.name}".red }
            table_diff.stale_ignored_columns.each do |c|
              lines << "    ~ #{c.name} (ignored but gone)".yellow
            end

            if verbose
              table_diff.auto_ignored_columns.each do |c|
                lines << "      #{c.name} [#{c.plugin}] (auto-ignored from plugin)".cyan
              end
            end
          end
          sections << lines.join("\n")
        end

        if sections.any?
          puts sections.join("\n\n")
          puts
          puts "Suggested actions:".bold
          puts "  migrations/bin/cli schema add <table>"
          puts "  migrations/bin/cli schema ignore <table> [--reason \"...\"]"
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
end
