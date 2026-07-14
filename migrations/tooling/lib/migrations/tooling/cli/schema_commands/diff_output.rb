# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        # Shared presentation of `Schema.diff` results for the `schema diff`
        # and `check schema` commands.
        module DiffOutput
          private

          def display_diff(result, database:, verbose: false)
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
              display_suggested_actions(result, database)
            else
              puts "✓ No differences found".green
            end
          end

          # Only suggests actions that match the actual findings: commands
          # first, then the file edits, grouped under the config file path.
          def display_suggested_actions(result, database)
            commands = suggested_commands(result)
            file_edits = suggested_file_edits(result)
            return if commands.empty? && file_edits.empty?

            puts
            puts "Suggested actions:".bold
            commands.each { |command| puts "  #{command}" }

            if file_edits.any?
              puts if commands.any?
              tables_dir = File.join(relative_config_path(database), "tables")
              puts "  In #{tables_dir}/<table>.rb:"
              file_edits.each { |file_edit| puts "    - #{file_edit}" }
            end
          end

          def suggested_commands(result)
            commands = []

            if result.unconfigured_tables.any?
              commands << "#{Migrations::CLI::BIN} schema add <table>"
              commands << "#{Migrations::CLI::BIN} schema ignore <table> [--reason \"...\"]"
            end

            if result.stale_ignored_tables.any?
              commands << "#{Migrations::CLI::BIN} schema unignore <table>"
            end

            commands
          end

          def suggested_file_edits(result)
            file_edits = []

            if result.table_diffs.any? { |td| td.unconfigured_columns.any? }
              file_edits << "add new columns to the `include` list or `ignore` them with a reason"
            end

            if result.table_diffs.any? { |td| td.missing_columns.any? }
              file_edits << "remove columns that no longer exist from the `include` list"
            end

            if result.table_diffs.any? { |td| td.stale_ignored_columns.any? }
              file_edits << "remove columns that no longer exist from the `ignore` list"
            end

            if result.missing_tables.any?
              file_edits << "delete the file if the table no longer exists"
            end

            file_edits
          end

          def relative_config_path(database)
            path = Pathname.new(schema.config_path(database))
            path.relative_path_from(Pathname.pwd).to_s
          rescue ArgumentError
            path.to_s
          end

          def filter_table_diffs(table_diffs, verbose:)
            return table_diffs if verbose

            table_diffs.select(&:actionable?)
          end
        end
      end
    end
  end
end
