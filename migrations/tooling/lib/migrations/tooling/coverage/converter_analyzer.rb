# frozen_string_literal: true

module Migrations
  module Tooling
    module Coverage
      # Analyses a single converter's sources: the union of IntermediateDB
      # columns it writes via `.create` across all of its step and helper
      # sources, and the call sites that reference models that don't exist.
      # Unioning per model across every call site means a column written in
      # only one branch of a conditional still counts as covered.
      class ConverterAnalyzer
        # `written_columns` per model name; `unknown_models` call site
        # locations per non-resolving model name.
        Result = Data.define(:written_columns, :unknown_models)

        # @param converter_path [String] the converter's root source directory
        def initialize(converter_path)
          @converter_path = converter_path
        end

        # @return [Result]
        def analyze
          written = {}
          unknown = {}

          source_files.each do |file|
            scan = CreateCallScanner.scan(File.read(file), path: display_path(file))

            scan.columns.each { |model, columns| (written[model] ||= Set.new).merge(columns) }
            scan.unknown_models.each do |model, locations|
              (unknown[model] ||= []).concat(locations)
            end
          end

          Result.new(written_columns: written, unknown_models: unknown)
        end

        private

        def source_files
          Dir[File.join(@converter_path, "**", "*.rb")].sort
        end

        def display_path(file)
          Pathname.new(file).relative_path_from(Pathname.pwd).to_s
        rescue ArgumentError
          file
        end
      end
    end
  end
end
