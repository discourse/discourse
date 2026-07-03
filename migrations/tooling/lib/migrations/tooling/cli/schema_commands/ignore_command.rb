# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class IgnoreCommand < BaseCommand
          self.description = "Add a table to ignored.rb"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
            option "--reason <text>", "Optional reason for ignoring the table."
          end

          one :table_name, "The name of the table to ignore."

          def call
            return print_usage if @options[:help]
            require_positional!(table_name, "table_name")

            database = selected_database
            schema.ignore_table(table_name, reason: @options[:reason], database:)
            puts "✓ Added #{table_name} to ignored.rb".green
          end
        end
      end
    end
  end
end
