# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class ValidateCommand < BaseCommand
          self.description = "Validate schema configuration against the database"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
          end

          def call
            return print_usage if @options[:help]

            database = selected_database
            errors = schema.validate(database:)
            print_validation_errors(errors)

            puts "✓ Schema valid".green
          end

          private

          def print_validation_errors(errors)
            return if errors.empty?

            errors.each { |e| puts "✗ #{e}".red }
            puts
            error_count = errors.size
            puts "#{error_count} #{"error".pluralize(error_count)}"
            exit 1
          end
        end
      end
    end
  end
end
