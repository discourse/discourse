# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    # Shortens text shown to the authoring agent with a visible marker, so the agent never
    # mistakes a cut value for the complete one.
    module Truncation
      def self.text(value, max_length)
        value = value.to_s
        return value if value.length <= max_length

        "#{value[0, max_length]}… [truncated, #{value.length} chars total]"
      end
    end
  end
end
