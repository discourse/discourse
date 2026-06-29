# frozen_string_literal: true

module Migrations
  module Converters
    module CLI
      class ConvertCommand < Migrations::CLI::Command
        class Error < StandardError
          include Migrations::CLI::PresentableError
        end

        self.description = "Convert a source dump into the IntermediateDB"

        options do
          option "-h/--help", "Print out help."
          option "--settings <path>", "Path of the settings file."
          option "--reset", "Reset the database before converting data."
          option "--only <steps>",
                 "Run only the specified steps (comma-separated).",
                 default: [],
                 type: STEP_LIST
          option "--skip <steps>",
                 "Skip the specified steps (comma-separated).",
                 default: [],
                 type: STEP_LIST
          option "--max-parallel-steps <count>",
                 "Maximum number of steps to run at the same time. " \
                   "Caps the source DB connections a run opens; defaults to the worker pool size.",
                 type: Integer
          option "--no-fork",
                 "Run each step inline in one process instead of forking workers. " \
                   "Forces serial execution; meant for debugging (a breakpoint in a " \
                   "step's `process` stops in the main run, not an unreachable child)."
        end

        one :converter_type, "The converter to run (e.g. discourse)."

        def call
          return print_usage if @options[:help]

          type =
            require_positional!(
              converter_type,
              "converter_type",
              hint: valid_names_message,
            ).downcase
          validate_converter_type!(type)

          settings = load_settings(type)

          Database.delete_database(settings[:intermediate_db][:path]) if @options[:reset]

          converter = "migrations/converters/#{type}/converter".camelize.constantize
          converter.new(settings).run(
            only_steps: @options[:only],
            skip_steps: @options[:skip],
            max_parallel_steps: @options[:max_parallel_steps],
            no_fork: @options[:no_fork] || false,
          )
        end

        private

        def validate_converter_type!(type)
          return if Converters.names.include?(type)

          raise Error, <<~MSG
            Unknown converter name: #{type}
            #{valid_names_message}
          MSG
        end

        def valid_names_message
          "Valid names are: #{Converters.names.join(", ")}"
        end

        def load_settings(type)
          settings_path = @options[:settings] || Converters.default_settings_path(type)
          settings_path = File.expand_path(settings_path, Dir.pwd)

          raise Error, "Settings file not found: #{settings_path}" unless File.exist?(settings_path)

          YAML.safe_load(File.read(settings_path), symbolize_names: true)
        end
      end
    end
  end
end
