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

        # Tables whose schema lands before the converter writes that fill them,
        # keyed by model name. This is a temporary exemption for a feature split
        # across PRs: without it the coverage gate would stay red on the schema PR
        # until the writer PR merges.
        #
        # It relaxes only the "writes every column" check, and only for these
        # tables. The unknown-column and unknown-model checks still run, so typos
        # are still caught. It also clears itself: once the reference converter
        # covers a listed table in full, the stale-entry guard fails the check until
        # the entry is removed. So we don't need to point at a PR or branch to track
        # removal; each value just says why the table is pending.
        PENDING_COVERAGE = {
          "PostEvent" => "the Posts step that writes these rows lands after this schema",
          "PostLink" => "the Posts step that writes these rows lands after this schema",
          "PostMention" => "the Posts step that writes these rows lands after this schema",
          "PostPoll" => "the Posts step that writes these rows lands after this schema",
          "PostQuote" => "the Posts step that writes these rows lands after this schema",
          "PostUpload" => "the Posts step that writes these rows lands after this schema",
        }.freeze

        class Error < StandardError
          include Migrations::CLI::PresentableError
        end

        def self.run
          new.run
        end

        # @param pending [Hash{String => String}] tables exempt from the reference
        #   "writes every column" assertion, keyed by model name. Defaults to
        #   {PENDING_COVERAGE}; injected in tests.
        def initialize(pending: PENDING_COVERAGE)
          @pending = pending
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

          # A pending table the reference now covers in full (or that the schema no
          # longer has) is a stale exemption. Fail until it's removed, so the
          # relaxation can't hide a later regression.
          stale = stale_pending(expected, reference_written)
          if stale.any?
            report_stale_pending(expected, stale)
            passed = false
          end

          # Only the reference must cover the full schema. Pending tables are held
          # out until their writes land (see PENDING_COVERAGE).
          asserted = expected.reject { |model_name, _| pending?(model_name) }
          missing = missing_columns(asserted, reference_written)
          if missing.any?
            report_missing(expected, missing)
            passed = false
          end

          if passed
            column_count = asserted.values.sum { |model| model.columns.size }
            puts "✓ The #{REFERENCE_CONVERTER} converter covers all #{column_count} IntermediateDB columns across #{asserted.size} tables.".green
            report_pending(expected) if @pending.any?
          end

          passed
        end

        private

        def pending?(model_name)
          @pending.key?(model_name)
        end

        # @return [Array<String>] model names listed as pending that no longer
        #   warrant it: either fully covered by the reference, or gone from the
        #   schema entirely.
        def stale_pending(expected, written)
          @pending.keys.select do |model_name|
            model = expected[model_name]
            next true unless model

            (model.columns - written.fetch(model_name, Set.new).to_a).empty?
          end
        end

        def report_stale_pending(expected, stale)
          puts "✗ The #{REFERENCE_CONVERTER} converter now covers tables still listed as pending coverage.".red
          puts "  Remove these from PENDING_COVERAGE — the writes they waited on have landed:"
          puts

          stale
            .sort_by { |model_name| expected[model_name]&.table_name || model_name }
            .each do |model_name|
              table = expected[model_name]&.table_name || model_name
              puts "  #{table} — #{@pending.fetch(model_name)}"
            end

          puts
        end

        def report_pending(expected)
          puts
          puts "  #{@pending.size} #{"table".pluralize(@pending.size)} held out of the gate, pending their converter writes:".yellow
          @pending
            .keys
            .sort_by { |model_name| expected[model_name]&.table_name || model_name }
            .each do |model_name|
              table = expected[model_name]&.table_name || model_name
              puts "    #{table} — #{@pending.fetch(model_name)}".yellow
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
