# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowTest::PastedResponse
    def self.items_for(response)
      value = response.respond_to?(:to_unsafe_h) ? response.to_unsafe_h : response
      value = parse(value) if value.is_a?(String)
      Array
        .wrap(value)
        .map do |entry|
          { "json" => entry.is_a?(Hash) ? entry.deep_stringify_keys : { "data" => entry } }
        end
    end

    def self.parse(text)
      JSON.parse(text)
    rescue JSON::ParserError
      text
    end
  end
end
