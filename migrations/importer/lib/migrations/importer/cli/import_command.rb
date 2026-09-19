# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class ImportCommand < Migrations::CLI::Command
        requires_rails!

        self.description = "Import the IntermediateDB into a Discourse database"

        options do
          option "-h/--help", "Print out help."
          option "--reset", "Reset MappingsDB before importing data."
          option "--only <steps>",
                 "Run only the specified steps (comma-separated).",
                 default: [],
                 type: STEP_LIST
          option "--skip <steps>",
                 "Skip the specified steps (comma-separated).",
                 default: [],
                 type: STEP_LIST
        end

        def call
          return print_usage if @options[:help]

          Importer.execute(reset: @options[:reset], only: @options[:only], skip: @options[:skip])
        end
      end
    end
  end
end
