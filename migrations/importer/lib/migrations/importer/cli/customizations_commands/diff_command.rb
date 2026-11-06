# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      module CustomizationsCommands
        # Rails-free: it only talks to the two databases through `pg`.
        class DiffCommand < Migrations::CLI::Command
          LIST = ->(value) { value.to_s.split(",").map(&:strip).reject(&:empty?) }
          WHERE_FLAG = "--where"

          self.description =
            "Diff two Discourse databases (e.g. restored before/after dumps) to find what changed"

          options do
            option "-h/--help", "Print out help."
            option "--before <conninfo>", "Database with the earlier state (libpq conninfo or URL)."
            option "--after <conninfo>", "Database with the later state (libpq conninfo or URL)."
            option "--schema <name>",
                   "Schema to diff.",
                   default: Customizations::Diff::Defaults::SCHEMA
            option "--only <tables>", "Diff only these tables (comma-separated).", type: LIST
            option "--skip <tables>",
                   "Skip these tables in addition to the defaults (comma-separated).",
                   type: LIST
            option "--include <tables>",
                   "Diff these tables even though they are skipped by default (comma-separated).",
                   type: LIST
            option "--no-default-skips", "Do not skip the content/activity tables."
            option "--where <TABLE=SQL>",
                   "Compare only rows matching SQL in TABLE; repeat for more tables " \
                     "(default: #{Customizations::Diff::Defaults::ROW_FILTERS.map { |t, w| "#{t}=#{w}" }.join(", ")})."
            option "--ignore-columns <columns>",
                   "Columns whose changes do not count (comma-separated; default: " \
                     "#{Customizations::Diff::Defaults::IGNORE_COLUMNS.join(",")}).",
                   type: LIST
            option "--max-rows <n>",
                   "Report counts only for tables larger than this.",
                   type: Integer,
                   default: Customizations::Diff::Defaults::MAX_ROWS
            option "--full", "Print full values instead of snippets."
            option "--json <path>", "Also write a machine-readable report (input for `plan`)."
          end

          # Samovar keeps only the last value of a repeated option, so `--where`
          # pairs are taken out before it parses.
          def parse(input)
            @where_values = []
            remaining = []
            index = 0
            while index < input.size
              token = input[index]
              if token == "--"
                remaining.concat(input[index..])
                break
              elsif token == WHERE_FLAG && index + 1 < input.size
                @where_values << input[index + 1]
                index += 2
              else
                remaining << token
                index += 1
              end
            end

            input.replace(remaining)
            super(input)
          end

          def call
            return print_usage if @options[:help]
            if @options[:before].blank? || @options[:after].blank?
              raise Customizations::Error, "both --before and --after are required"
            end

            runner =
              Customizations::Diff::Runner.new(
                before: @options[:before],
                after: @options[:after],
                schema: @options[:schema],
                only: @options[:only] || [],
                skip: @options[:skip] || [],
                include: @options[:include] || [],
                default_skips: !@options[:no_default_skips],
                row_filters:,
                ignore_columns:
                  @options[:ignore_columns] || Customizations::Diff::Defaults::IGNORE_COLUMNS,
                max_rows: @options[:max_rows],
              ).run

            Customizations::Diff::Printer.new(runner, full: @options[:full]).print

            if (path = @options[:json])
              runner.write_json(path)
              puts "JSON report written to #{path}"
            end
          end

          def row_filters
            @where_values.to_h do |value|
              table, condition = value.split("=", 2)
              raise Customizations::Error, "--where expects TABLE=SQL" if condition.nil?
              [table, condition]
            end
          end
        end
      end
    end
  end
end
