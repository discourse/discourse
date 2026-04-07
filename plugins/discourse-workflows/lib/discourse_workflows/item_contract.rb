# frozen_string_literal: true

module DiscourseWorkflows
  module ItemContract
    class Error < StandardError
    end

    def self.validate_items!(items, source:)
      return unless Rails.env.local?
      unless items.is_a?(Array) && items.all? { |i| i.is_a?(Hash) && i.key?("json") }
        raise Error,
              "Invalid items from #{source}: expected Array<{ 'json' => Hash }>, got #{items.inspect.truncate(200)}"
      end
    end

    def self.validate_output_arrays!(result, source:)
      return unless Rails.env.local?
      unless result.is_a?(Array) && result.all? { |inner| inner.is_a?(Array) }
        raise Error, "#{source}: execute must return Array<Array<Item>>, got #{result.class}"
      end
      result.each { |inner| validate_items!(inner, source: source) }
    end
  end
end
