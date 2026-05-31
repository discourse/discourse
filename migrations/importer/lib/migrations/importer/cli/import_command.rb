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
          option "--only <steps>", "Run only the specified steps (comma-separated)."
          option "--skip <steps>", "Skip the specified steps (comma-separated)."
        end

        def call
          return print_usage if @options[:help]

          Migrations::Importer.execute(
            reset: @options[:reset],
            only: step_names(@options[:only]),
            skip: step_names(@options[:skip]),
          )
        end

        private

        def step_names(class_names)
          class_names.presence&.split(",")&.map { |name| name.strip.demodulize.underscore } || []
        end
      end
    end
  end
end
