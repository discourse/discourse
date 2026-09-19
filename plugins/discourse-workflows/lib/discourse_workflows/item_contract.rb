# frozen_string_literal: true

module DiscourseWorkflows
  module ItemContract
    VALID_ITEM_KEYS = %w[json pairedItem error index].freeze

    class Error < StandardError
    end

    def self.validate_items!(items, source:)
      unless items.is_a?(Array) &&
               items.all? { |item| item.is_a?(Hash) && item["json"].is_a?(Hash) }
        raise Error,
              "Invalid items from #{source}: expected Array<{ 'json' => Hash }>, got #{items.inspect.truncate(200)}"
      end

      items.each do |item|
        validate_item_keys!(item, source:)
        validate_paired_item!(item, source:)
      end
    end

    def self.validate_output_arrays!(result, source:, ports: nil)
      unless result.is_a?(Array) && result.all? { |inner| inner.is_a?(Array) }
        raise Error, "#{source}: execute must return Array<Array<Item>>, got #{result.class}"
      end

      if ports && result.length > ports.length
        raise Error,
              "#{source}: execute returned #{result.length} outputs, but node declares #{ports.length}"
      end

      result.each { |inner| validate_items!(inner, source: source) }
    end

    def self.validate_paired_item!(item, source:)
      paired_item = Item.paired_item(item)
      return if paired_item.nil?

      entries = paired_item.is_a?(Array) ? paired_item : [paired_item]
      unless entries.all? { |entry| valid_paired_item_entry?(entry) }
        raise Error,
              "Invalid pairedItem from #{source}: expected Integer or { 'item' => Integer, 'input' => Integer? }, got #{paired_item.inspect.truncate(200)}"
      end
    end

    def self.validate_item_keys!(item, source:)
      unknown_keys = item.keys - VALID_ITEM_KEYS
      return if unknown_keys.empty?

      raise Error,
            "Invalid item keys from #{source}: expected #{VALID_ITEM_KEYS.inspect}, got #{unknown_keys.inspect.truncate(200)}"
    end

    def self.valid_paired_item_entry?(entry)
      return true if entry.is_a?(Integer)
      return false unless entry.is_a?(Hash)

      item_index = entry["item"]
      input_index = entry["input"]
      item_index.is_a?(Integer) && (input_index.nil? || input_index.is_a?(Integer))
    end
  end
end
