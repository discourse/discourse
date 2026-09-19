# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class UnignoreCommand < BaseCommand
          self.description = "Remove a table from ignored.rb"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
          end

          one :table_name, "The name of the table to remove from ignored.rb."

          def call
            return print_usage if @options[:help]
            require_positional!(table_name, "table_name")

            database = selected_database
            schema.unignore_table(table_name, database:)
            puts "✓ Removed #{table_name} from ignored.rb".green
          end
        end
      end
    end
  end
end
