# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class DiffCommand < BaseCommand
          include DiffOutput

          self.description = "Show differences between configuration and database"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
            option "--verbose", "Show auto-ignored plugin columns."
          end

          def call
            return print_usage if @options[:help]

            database = selected_database
            result = schema.diff(database:)
            display_diff(result, database:, verbose: @options[:verbose])
          end
        end
      end
    end
  end
end
