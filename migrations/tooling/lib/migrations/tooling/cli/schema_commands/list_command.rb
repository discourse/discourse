# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class ListCommand < BaseCommand
          self.description = "List configured tables and enums, plus ignored table counts"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
          end

          def call
            return print_usage if @options[:help]

            database = selected_database
            schema.ensure_ready!(database:)

            tables = schema.tables
            ignored = schema.ignored_tables
            effective_ignored = schema.effective_ignored_table_names(database:)
            enums = schema.enums

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
        end
      end
    end
  end
end
