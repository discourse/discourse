# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      module Commands
        class Schema < Core::CLI::Command
          self.description = "Schema management commands"

          class GenerateSchema < Core::CLI::Command
            self.description = "Generate schema files from DSL"

            def call
              warn("Not yet implemented")
            end
          end

          class Validate < Core::CLI::Command
            self.description = "Validate schema configuration"

            options { option "--strict", "Fail on warnings" }

            def call
              warn("Not yet implemented")
            end
          end

          class Diff < Core::CLI::Command
            self.description = "Show differences from database"

            def call
              warn("Not yet implemented")
            end
          end

          nested :command,
                 { "generate" => GenerateSchema, "validate" => Validate, "diff" => Diff },
                 default: nil

          def call
            if @command
              @command.call
            else
              show_usage
            end
          end

          def show_usage
            puts "Usage: disco schema <command>"
            puts
            puts "Commands:"
            puts "  generate    Generate schema files from DSL"
            puts "  validate    Validate schema configuration"
            puts "  diff        Show differences from database"
          end
        end
      end
    end
  end
end
