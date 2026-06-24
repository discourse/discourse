# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module Coverage
      # Asserts that the reference converter writes every IntermediateDB
      # column, and that no converter writes columns or models that don't
      # exist in the schema — those call sites would raise at runtime, and
      # typically are leftovers of a schema change. Analysing every discovered
      # converter also means an unverifiable call site (a `**` splat or
      # non-literal keyword) fails loudly even in a non-reference converter.
      # Prints its findings and returns whether the check passed.
      class ReferenceCheck
        # The Discourse converter is the reference implementation: the
        # IntermediateDB schema is modelled on Discourse's own schema, so it
        # is the one converter expected to populate every column. This is
        # structural, not a configurable role, so it is hardcoded.
        REFERENCE_CONVERTER = "discourse"

        # The post-embed linkage tables are written by the shared
        # `Migrations::Converters::EmbedBuffer#write_for`, not by per-converter
        # `IntermediateDB::Post*.create` call sites. The scanner only reads each
        # converter's own source, so it never sees those writes, and the tables
        # would otherwise look uncovered forever. So they're held out of the
        # reference "writes every column" check, by model name.
        #
        # This is not a blanket pass. The unknown-column, unknown-model and `**`
        # splat checks still apply to these tables. And if a converter ever covers
        # one with explicit `create` calls, the stale-entry guard flags it for
        # removal. The drift protection this check would otherwise give (a schema
        # column nothing writes) lives in EmbedBuffer's own spec instead.
        EMBED_BUFFER_TABLES = %w[
          PostEvent
          PostLink
          PostMention
          PostPoll
          PostQuote
          PostUpload
        ].freeze

        class Error < StandardError
          include Migrations::CLI::PresentableError
        end

        def self.run
          new.run
        end

        # @param exempt_tables [Array<String>] model names held out of the reference
        #   "writes every column" assertion. Defaults to {EMBED_BUFFER_TABLES};
        #   injected in tests.
        def initialize(exempt_tables: EMBED_BUFFER_TABLES)
          @exempt_tables = exempt_tables
        end

        def run
          converters = Migrations::Converters.names
          ensure_reference_present!(converters)

          results = converters.to_h { |name| [name, analyze(name)] }
          expected = SchemaColumns.call
          reference_written = results.fetch(REFERENCE_CONVERTER).written_columns

          passed = true

          # Unknown columns and models are errors for every converter, not
          # just the reference: there is no legitimate reason to write
          # something the schema doesn't know.
          converters.each do |name|
            unknown_columns = unknown_columns(expected, results.fetch(name).written_columns)
            unknown_models = results.fetch(name).unknown_models

            if unknown_columns.any? || unknown_models.any?
              report_unknown(name, expected, unknown_columns, unknown_models)
              passed = false
            end
          end

          # An exempt table the reference now covers in full (or that the schema no
          # longer has) no longer needs holding out. Fail until it's removed, so the
          # exemption can't hide a later regression.
          stale = stale_exemptions(expected, reference_written)
          if stale.any?
            report_stale_exemptions(expected, stale)
            passed = false
          end

          # Only the reference must cover the full schema. The embed-buffer tables
          # are held out (see EMBED_BUFFER_TABLES).
          asserted = expected.reject { |model_name, _| exempt?(model_name) }
          missing = missing_columns(asserted, reference_written)
          if missing.any?
            report_missing(expected, missing)
            passed = false
          end

          if passed
            column_count = asserted.values.sum { |model| model.columns.size }
            puts "✓ The #{REFERENCE_CONVERTER} converter covers all #{column_count} IntermediateDB columns across #{asserted.size} tables.".green
            report_exempt_tables(expected) if @exempt_tables.any?
          end

          passed
        end

        private

        def exempt?(model_name)
          @exempt_tables.include?(model_name)
        end

        # @return [Array<String>] exempt model names that no longer need holding out:
        #   either fully covered by the reference, or gone from the schema entirely.
        def stale_exemptions(expected, written)
          @exempt_tables.select do |model_name|
            model = expected[model_name]
            next true unless model

            (model.columns - written.fetch(model_name, Set.new).to_a).empty?
          end
        end

        def report_stale_exemptions(expected, stale)
          puts "✗ The #{REFERENCE_CONVERTER} converter now covers tables held out by EMBED_BUFFER_TABLES.".red
          puts "  Remove them — explicit create calls cover these now:"
          puts

          stale
            .sort_by { |model_name| expected[model_name]&.table_name || model_name }
            .each { |model_name| puts "  #{expected[model_name]&.table_name || model_name}" }

          puts
        end

        def report_exempt_tables(expected)
          puts
          puts "  #{@exempt_tables.size} #{"table".pluralize(@exempt_tables.size)} written by EmbedBuffer#write_for, held out of the per-converter check:".yellow
          @exempt_tables
            .sort_by { |model_name| expected[model_name]&.table_name || model_name }
            .each do |model_name|
              puts "    #{expected[model_name]&.table_name || model_name}".yellow
            end
        end

        # @return [Hash{String => Array<Symbol>}] uncovered columns per model,
        #   only for models that have at least one.
        def missing_columns(expected, written)
          expected.each_with_object({}) do |(model_name, model), missing|
            uncovered = model.columns - written.fetch(model_name, Set.new).to_a
            missing[model_name] = uncovered if uncovered.any?
          end
        end

        # @return [Hash{String => Array<Symbol>}] written columns the model's
        #   `create` doesn't accept, per model. Models outside the generated
        #   contract (manual models like Upload) have a bespoke API and are
        #   skipped.
        def unknown_columns(expected, written)
          written.each_with_object({}) do |(model_name, columns), unknown|
            model = expected[model_name]
            next unless model

            extra = columns.to_a - model.columns
            unknown[model_name] = extra.sort if extra.any?
          end
        end

        def report_unknown(converter_name, expected, unknown_columns, unknown_models)
          if unknown_columns.any?
            puts "✗ The #{converter_name} converter writes columns that don't exist in the IntermediateDB schema".red
            puts "  (stale call sites after a schema change?):"
            puts

            unknown_columns
              .keys
              .sort_by { |model_name| expected[model_name].table_name }
              .each do |model_name|
                puts "  #{expected[model_name].table_name}: #{unknown_columns[model_name].join(", ")}"
              end

            puts
          end

          if unknown_models.any?
            puts "✗ The #{converter_name} converter writes to IntermediateDB models that don't exist:".red
            puts

            unknown_models.keys.sort.each do |model_name|
              puts "  #{model_name} (#{unknown_models[model_name].join(", ")})"
            end

            puts
          end
        end

        def report_missing(expected, missing)
          puts "✗ The #{REFERENCE_CONVERTER} converter does not write every IntermediateDB column.".red
          puts "  Acknowledge each column in the converter (pass it explicitly, `column: nil` if the source has no value):"
          puts

          column_count = 0
          missing
            .keys
            .sort_by { |model_name| expected[model_name].table_name }
            .each do |model_name|
              columns = missing[model_name].sort
              column_count += columns.size
              puts "  #{expected[model_name].table_name}: #{columns.join(", ")}"
            end

          puts
          puts "#{column_count} #{"column".pluralize(column_count)} across #{missing.size} #{"table".pluralize(missing.size)} not covered.".red
        end

        def analyze(converter_name)
          ConverterAnalyzer.new(Migrations::Converters.path_of(converter_name)).analyze
        end

        def ensure_reference_present!(converters)
          return if converters.include?(REFERENCE_CONVERTER)

          raise Error, <<~MSG.strip
            Reference converter '#{REFERENCE_CONVERTER}' was not found among the discovered converters: #{converters.join(", ")}.
            The coverage check cannot run without it.
          MSG
        end
      end
    end
  end
end
