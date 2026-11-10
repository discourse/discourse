# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    # Shrinks workflow items shown to the authoring agent and marks every cut, so the agent
    # never mistakes a sample for the complete data.
    class Sample
      NOTE =
        "Sample truncated: compare items with total_items; shortened values are marked [truncated, ...]."
      MAX_ARRAY_LENGTH = 10

      # ports: one array of items per output. totals: real item counts when ports were capped earlier.
      def self.call(ports, totals: nil, max_items: 3, max_chars: 4_000, max_string_length: 500)
        new(max_string_length).call(ports, totals, max_items, max_chars)
      end

      def initialize(max_string_length)
        @max_string_length = max_string_length
        @truncated = false
      end

      def call(ports, totals, max_items, max_chars)
        ports = Array(ports).map { |items| Array(items) }
        totals ||= ports.map(&:length)
        outputs = nil

        [max_items, 1, 0].uniq.each do |limit|
          outputs =
            ports.each_with_index.map do |items, index|
              shown = items.first(limit)
              @truncated ||= totals[index].to_i > shown.length
              { total_items: totals[index].to_i, items: shown.map { |item| trim(item) } }
            end
          break if outputs.to_json.length <= max_chars
        end

        { outputs: outputs, truncated: (NOTE if @truncated) }.compact
      end

      private

      def trim(value)
        case value
        when String
          @truncated ||= value.length > @max_string_length
          Truncation.text(value, @max_string_length)
        when Array
          trimmed = value.first(MAX_ARRAY_LENGTH).map { |element| trim(element) }
          if value.length > MAX_ARRAY_LENGTH
            @truncated = true
            trimmed << "[truncated, #{value.length} items total]"
          end
          trimmed
        when Hash
          value.transform_values { |element| trim(element) }
        else
          value
        end
      end
    end
  end
end
