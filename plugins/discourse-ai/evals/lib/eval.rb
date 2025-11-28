# frozen_string_literal: true

require "csv"

module DiscourseAi
  module Evals
    # Lightweight data object that loads eval definitions from disk.
    #
    # Each YAML file under `evals/cases` is parsed into an instance that exposes
    # metadata (id, description, feature) and the normalized args needed by the
    # Playground to execute the evaluation. The class intentionally performs no
    # business logic; it only validates and prepares the data for consumers.
    class Eval
      attr_reader :path,
                  :name,
                  :description,
                  :id,
                  :args,
                  :vision,
                  :feature,
                  :expected_output,
                  :expected_output_regex,
                  :expected_tool_call,
                  :judge

      class EvalError < StandardError
        attr_reader :context

        def initialize(message, context)
          super(message)
          @context = context
        end
      end

      CASES_GLOB = File.join(__dir__, "../cases", "*/*.yml")

      # @return [Array<DiscourseAi::Evals::Eval>] all cases sorted by path so
      #   the CLI emits a deterministic order.
      def self.available_cases
        Dir.glob(CASES_GLOB).sort.map { |path| new(path: path) }
      end

      # @param path [String] absolute path to the YAML definition file.
      # @raise [ArgumentError] when a required key (like `feature`) is missing.
      def initialize(path:, initial_data: nil)
        yaml = initial_data&.symbolize_keys || YAML.load_file(path).symbolize_keys
        initialize_from_hash(yaml, path: path, base_dir: File.dirname(path))
      end

      def self.from_dataset_csv(path:, feature:)
        raise ArgumentError, "Feature is required for datasets" if feature.blank?

        normalized_path = File.expand_path(path)
        rows = CSV.read(normalized_path, headers: true)
        raise ArgumentError, "Dataset '#{path}' has no rows" if rows.empty?

        rows.each_with_index.map do |row, index|
          normalized = normalize_dataset_row(row)
          content = normalized[:content].to_s.strip
          expected = normalized[:expected_output].to_s

          if content.blank? || expected.blank?
            raise ArgumentError, "Dataset rows must define 'content' and 'expected_output'"
          end

          attrs = {
            id: "dataset-#{File.basename(path, File.extname(path))}-#{index + 1}",
            name: "dataset row #{index + 1}",
            description: "Dataset row #{index + 1} from #{File.basename(path)}",
            feature: feature,
            args: {
              input: content,
            },
            expected_output: expected.strip,
          }

          new(path: normalized_path, initial_data: attrs)
        end
      end

      def print
        puts "#{id}: #{description} (feature: #{feature})"
      end

      # @return [Hash] plain data used by Recorder and CLI output.
      def to_json
        {
          path: @path,
          name: @name,
          description: @description,
          id: @id,
          feature: @feature,
          args: @args,
          vision: @vision,
          expected_output: @expected_output,
          expected_output_regex: @expected_output_regex,
        }.compact
      end

      private

      def initialize_from_hash(yaml, path:, base_dir:)
        @path = path
        @name = yaml[:name]
        @id = yaml[:id]
        @description = yaml[:description]
        @vision = yaml[:vision]
        @feature = yaml[:feature]
        if @feature.blank?
          raise ArgumentError, "Eval '#{@id || @name || path}' must define a 'feature' key."
        end
        @expected_output = yaml[:expected_output]
        @expected_output_regex = yaml[:expected_output_regex]
        @expected_output_regex =
          Regexp.new(@expected_output_regex, Regexp::MULTILINE) if @expected_output_regex
        @expected_tool_call = yaml[:expected_tool_call]
        @expected_tool_call.symbolize_keys! if @expected_tool_call
        @judge = yaml[:judge]
        @judge.symbolize_keys! if @judge

        @args =
          if !yaml.key?(:args) || yaml[:args].nil?
            {}
          elsif yaml[:args].is_a?(Array)
            yaml[:args].map(&:symbolize_keys)
          else
            normalize_args(base_dir, yaml[:args])
          end
      end

      # Converts relative paths (e.g. asset fixtures) into absolute ones so the
      # runner can execute from any working directory.
      #
      # @param base_dir [String] original yaml file directory used as base.
      # @param values [Hash] raw args coming from the YAML file.
      # @return [Hash] symbolized args with absolute paths when relevant.
      def normalize_args(base_dir, values)
        args = values.symbolize_keys
        args.each do |key, value|
          if (key.to_s.include?("_path") || key.to_s == "path") && value.is_a?(String)
            args[key] = File.expand_path(File.join(base_dir, value))
          end
        end
        args
      end

      def self.normalize_dataset_row(row)
        row
          .to_h
          .each_with_object({}) do |(key, value), memo|
            next if key.nil?

            normalized_key = key.to_s.strip.downcase.gsub(/\s+/, "_").to_sym
            memo[normalized_key] = value
          end
      end
    end
  end
end
