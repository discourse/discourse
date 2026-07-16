# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module CheckCommands
        # `disco check coverage` — asserts that the reference converter covers
        # every IntermediateDB column. Runs without Rails.
        #
        # `--inspect <converter>` switches from the gate to a read-only report of
        # the columns a single converter writes, with per-model N/M coverage. It
        # is a debugging aid, not a gate, so it never changes the exit status.
        class CoverageCommand < Migrations::CLI::Command
          self.description = "Check converter coverage of the IntermediateDB schema"

          class Error < StandardError
            include Migrations::CLI::PresentableError
          end

          options do
            option "-h/--help", "Print out help."
            option "--inspect <converter>",
                   "Print one converter's covered columns instead of running the gate."
          end

          def call
            return print_usage if @options[:help]

            if (converter = @options[:inspect])
              inspect_converter(converter.downcase)
            else
              exit 1 unless run
            end
          end

          # Called directly by `CheckCommand#run_all`, so it must return the
          # pass/fail boolean rather than exiting.
          def run
            Coverage::ReferenceCheck.run
          end

          private

          def inspect_converter(converter_name)
            validate_converter!(converter_name)

            result =
              Coverage::ConverterAnalyzer.new(
                Migrations::Converters.path_of(converter_name),
              ).analyze
            written = result.written_columns
            expected = Coverage::SchemaColumns.call

            puts "Columns written by the '#{converter_name}' converter:"
            puts

            if written.empty? && result.unknown_models.empty?
              puts "  (no IntermediateDB.create calls found)"
              return
            end

            written.keys.sort.each do |model_name|
              columns = written[model_name].to_a.sort
              schema_count = expected[model_name]&.columns&.size
              coverage = schema_count ? "#{columns.size}/#{schema_count}" : columns.size.to_s
              puts "  #{model_name} (#{coverage}): #{columns.join(", ")}"

              if (model = expected[model_name]) && (extra = columns - model.columns).any?
                puts "    unknown #{"column".pluralize(extra.size)}: #{extra.join(", ")}".red
              end
            end

            result.unknown_models.keys.sort.each do |model_name|
              locations = result.unknown_models[model_name]
              puts "  #{model_name}: model does not exist (#{locations.join(", ")})".red
            end
          end

          def validate_converter!(converter_name)
            names = Migrations::Converters.names
            return if names.include?(converter_name)

            raise Error, <<~MSG.strip
              Unknown converter name: #{converter_name}
              Valid names are: #{names.join(", ")}
            MSG
          end
        end
      end
    end
  end
end
