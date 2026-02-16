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

      result.warnings.each { |w| puts I18n.t("schema.validate.warning", message: w).yellow }
      result.errors.each { |e| puts I18n.t("schema.validate.error", message: e).red }

      has_issues = result.errors.any? || (options[:strict] && result.warnings.any?)

      if has_issues
        puts
        errors_str = I18n.t("schema.validate.summary", count: result.errors.size)
        warnings_str = I18n.t("schema.validate.warning_summary", count: result.warnings.size)
        puts "#{errors_str}, #{warnings_str}"
        exit 1
      else
        puts I18n.t("schema.validate.valid").green
      end
    end

    desc "generate", "Generate SQL schema, Ruby models, and enum files"
    def generate
      load_rails!

      resolved = Schema.generate

      puts
      tables_str = I18n.t("schema.generate.tables", count: resolved.tables.size)
      enums_str = I18n.t("schema.generate.enums", count: resolved.enums.size)
      puts I18n.t("schema.generate.success", tables: tables_str, enums: enums_str).green
    end

    desc "resolve", "Show the resolved schema (for debugging)"
    def resolve
      load_rails!

      resolved = Schema.resolve

      puts I18n.t("schema.resolve.title")
      puts I18n.t("schema.resolve.separator")
      puts
      puts I18n.t("schema.resolve.tables_header", count: resolved.tables.size)
      resolved.tables.each do |table|
        pk = table.primary_key_column_names&.join(", ") || "id"
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
      Schema.ensure_ready!

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
      Schema.ensure_ready!

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
      puts I18n.t("schema.ignore.success", table: table_name).green
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
      puts I18n.t("schema.scaffold.success", path:).green
      puts
      puts I18n.t("schema.scaffold.next_steps")
      puts "  #{I18n.t("schema.scaffold.step_edit")}"
      puts "  #{I18n.t("schema.scaffold.step_validate")}"
    end

    desc "detect-plugins", "Regenerate the plugin manifest"
    method_option :force, type: :boolean, default: false, desc: "Force regeneration"
    def detect_plugins
      load_rails!

      manifest = Schema.plugin_manifest

      if options[:force] || !manifest.fresh?
        puts I18n.t("schema.detect_plugins.detecting")
        manifest.regenerate!
        puts I18n.t("schema.detect_plugins.updated").green
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

    def display_diff(result)
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

      if result.table_diffs.any?
        has_changes = true
        puts I18n.t("schema.diff.column_diffs")
        result.table_diffs.each do |table_diff|
          puts "  #{table_diff.table_name}:"

          table_diff.unknown_columns.each do |c|
            plugin_info = c.plugin ? " [#{c.plugin}]" : ""
            puts "    + #{c.name}#{plugin_info}"
          end

          table_diff.missing_columns.each { |c| puts "    - #{c.name}" }

          table_diff.stale_ignored_columns.each do |c|
            puts "    ~ #{I18n.t("schema.diff.stale_ignored_column", name: c.name)}"
          end
        end
        puts
      end

      if has_changes
        puts I18n.t("schema.diff.suggested_actions")
        puts "  #{I18n.t("schema.diff.action_scaffold")}"
        puts "  #{I18n.t("schema.diff.action_ignore")}"
      else
        puts I18n.t("schema.diff.no_differences").green
      end
    end
  end
end
