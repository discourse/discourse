# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      module Commands
        class Generate < Core::CLI::Command
          self.description = "Generate scaffolds"

          class Converter < Core::CLI::Command
            self.description = "Generate a new converter"

            options do
              option "--private", "Create as private converter (separate repo)"
              option "--output <path>", "Output directory for private converters"
            end

            one :name, "Converter name (e.g., phpbb, acme_corp)"

            def call
              if @name.nil?
                error("Converter name required")
                return
              end

              warn("Not yet implemented: generate converter #{@name}")
            end
          end

          class Step < Core::CLI::Command
            self.description = "Generate a new converter step"

            one :name, "Step name (e.g., users, posts)"

            def call
              if @name.nil?
                error("Step name required")
                return
              end

              warn("Not yet implemented: generate step #{@name}")
            end
          end

          nested :command, { "converter" => Converter, "step" => Step }, default: nil

          def call
            if @command
              @command.call
            else
              show_usage
            end
          end

          def show_usage
            puts "Usage: disco generate <type> <name>"
            puts
            puts "Types:"
            puts "  converter   Generate a new converter"
            puts "  step        Generate a new converter step"
          end
        end
      end
    end
  end
end
